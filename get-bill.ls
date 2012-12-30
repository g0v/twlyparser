require! \./lib/ly
require! <[optimist mkdirp fs async cheerio request ./lib/util]>

id = optimist.argv._

extractNames = (content) ->
    [_, role, names] = content.match /getLawMakerName\('(\w+)', '(.*)'\)/
    mly = names.split /\s+/ .filter (.length)
    [role, mly]

getBill = (id, cb) ->
    err <- mkdirp "source/bill/#{id}"
    file = "source/bill/#{id}/index.html"
    json = file.replace /\.html$/, '.json'

    extract = (body) ->
        parseBill id, body, (res) ->
            fs.writeFileSync json, JSON.stringify res, null 4
            cb res

    _, {size}? <- fs.stat json
    if size
        return cb require "./#json"

    _, {size}? <- fs.stat file
    if size
        extract fs.readFileSync file
    else
        body <- ly.getBillDetails id
        fs.writeFileSync file, body
        extract body


parseBill = (id, body, cb) ->
    $ = cheerio.load body
    info = {extracted: new Date!}


    $ 'table[summary="院會審議消息資料表格"] tr' .each ->
        key = @find \th .map -> @text!
        if key.length is 1 and key isnt /國會圖書館/
            key = key.0 - /：/
            content = @find \td
            [prop, value] = match key
            | /提案單位/ => [\propser_text, content.map(-> @text!).0]
            | \議案名稱 => [\summary, content.map(-> @text!).0]
            | \議案名稱 => [\summary, content.map(-> @text!).0]
            | \提案人 => extractNames content.html!
            | \連署人 => extractNames content.html!
            | \議案狀態 => [\status, content.map(-> @text!).0 - /^\s*|\s*$/g]
            | \關連議案 =>
                related = content.find \a .map -> [
                    * (@attr \onclick .match /queryBillDetail\('(\d+)',/).1
                    * @text! - /^\s*|\s*$/g
                ]
                [\related, related]
            | \相關附件 =>
                doc = content.find \a .map -> [
                    * (@text!match /(pdf|word)/i).1.toLowerCase!
                    * @attr \href
                ]
                [\doc, {[type, uri] for [type, uri] in doc}]
            | otherwise => [key, content.map(-> @text!).0]
            info[prop] = value
    cb info

info <- getBill id
if uri = info.doc.word
    console.log \has uri
    file = "source/bill/#{id}/file.doc"
    _, {size}? <- fs.stat file
    unless size?
        writer = with fs.createWriteStream file
            ..on \error -> throw it
            ..on \close -> console.log \done uri
            ..
        request {method: \GET, uri} .pipe writer
