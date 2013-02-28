require! \./lib/ly
require! <[optimist mkdirp fs async cheerio request ./lib/util]>

extractNames = (content) ->
    unless [_, role, names]? = content.match /getLawMakerName\('(\w+)', '(.*)'\)/
        return []
    names .= replace /\s(\S)\s(\S)(\s|$)/g (...args) -> " #{args.1}#{args.2} "
    names .= replace /黨團/ '黨團 '
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
            text = -> content.map(-> @text!).0
            [prop, value] = match key
            | /提案單位/ => [\propser_text text!]
            | \審查委員會 =>
                text!match /^本院/
                if text!match /^本院(.*?)(?:兩|三|四|五|六|七|八)?委員會$/
                    [\committee util.parseCommittee that.1]
                else
                    [\propser_text text!]
            | \議案名稱 => [\summary text!]
            | \提案人 => extractNames content.html!
            | \連署人 => extractNames content.html!
            | \議案狀態 => [\status text! - /^\s*|\s*$/g]
            | \關連議案 =>
                related = content.find \a .map -> [
                    * (@attr \onclick .match /queryBillDetail\('(\d+)',/).1
                    * @text! - /^\s*|\s*$/g
                ]
                [\related, related]
            | \相關附件 =>
                doc = content.find \a .map ->
                    href = @attr \href
                    href .= replace /^http:\/\/10.12.8.14:28080\//, 'http://misq.ly.gov.tw/'
                    [ href.match(/(pdf|doc)/i).1.toLowerCase!, href ]
                [\doc, {[type, uri] for [type, uri] in doc}]
            | otherwise => [key, text!]
            info[prop] = value if prop
    cb info


id = optimist.argv._
funcs = []
optimist.argv._.forEach (id) ->
    funcs.push (done) ->
        console.log id
        info <- getBill id
        return done! unless uri = info.doc.doc
        console.log \has uri
        if uri is /http:\/\/10\./
            console.error id, uri
            return done!
        file = "source/bill/#{id}/file.html"
        _, {size}? <- fs.stat file
        return done! if size?
        file = "source/bill/#{id}/file.doc"
        _, {size}? <- fs.stat file
        return done! if size?
        writer = with fs.createWriteStream file
            ..on \error -> throw it
            ..on \close -> console.log \done uri; done!
            ..
        request {method: \GET, uri} .pipe writer

<- async.waterfall funcs
console.log \done
