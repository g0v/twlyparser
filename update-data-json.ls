# Specify the range of gazette id, this script will update gazettes.json and index.json by
#
#   1. import gazettes.json and index.json into memory
#   2. download corresponding HTML files
#   3. parse downloaded HTML files to update 'gazettes' and 'index' data structure
#   4. update attribute 'files' of index data structure
#   5. save back to json file
#
# $ lsc update-data-json.ls --from <gazette id> --to <gazette id>

require! {Async:\async, optimist, request, ExecSync:\execSync, fs, cheerio, gazettes:\./data/gazettes, index:\./data/index}
require! \./lib/ly

srcDir = "source/meta"

usageThenExit = ->
    console.log "\n\tUsage: $ lsc update_date_json.ls --from <gazette id> [--to <gazette id>]"
    process.exit 1

syncCurlHTML = (id) ->
    console.log "get html for id: #id"
    cmd = "curl -X POST -d rangeCondition='$serial_number='#id" +
    " -d sortFieldListSource=file_seqno:0" +
    " -d queryIndexeListSource=0:lciv_commfile" +
    " -d fieldNameListSource=year,volume,book_id,book_id_chn,serial_number,subtitle,communique_type,meeting_date,publish_date,pdf_filename2,file_seqno,check_vod_flag" +
    " http://lci.ly.gov.tw/LyLCEW/lcivCommDetail.action"
    ExecSync.exec "#cmd > ./#srcDir/#id.html"

# to skip downloaded HTML, return ids that we have not downloaded yet
getDownloadList = (fromId, toId) ->
    list = []
    for id in [fromId to toId] => let id
        list.push id if !fs.existsSync "#srcDir/#id.html"
    return list

parseTWDate = ->
    [_, y, m, d] = it.match /(\d+)\/(\d+)\/(\d+)/
    new Date +y + 1911, +m-1, +d

# parse downloaded HTML and update 'gazettes' and 'index' data structure
parseHTML = (gazettes, index, gazette, file) ->
    if gazettes[gazette]?
        console.error "#gazette already exists.  skipping"
        return
    data = fs.readFileSync file, \utf8
    date = null
    $ = cheerio.load data
    $ \table .find 'tr[id^=searchResult]' .each ->
        [_, type, summary, _, _, _, date?] = @.find \td .map -> @.text! - /^\s+|[\.\s]+$/g
        $(@)find 'input[value=原始檔]' .each ->
            [year, vol, book, seq] = @.attr 'onclick' .match /(\d+)/g
            ref = {year, vol, book, seq}
            gazettes[gazette] ?= { year, vol, date: parseTWDate date }
            index.push {gazette, book, seq, type, summary }

# make a function object that could be invoked by Async.parallel
mkWrapper = (indexJson, which, dataObj, id, type) ->
    return (cb) ->
        # update index.json object if retrieved file link
        indexJson[which].files <- ly.lci.getFileList dataObj, id, type
        console.log \got which, id, indexJson[which].files
        cb!

## Main logic ##

# check command line arguments
{from:fromId, to:toId} = optimist.argv
usageThenExit! if !fromId
toId = fromId if !toId
ids = [fromId to toId]
ids.forEach (v, idx, list) -> list[idx] = v.toString!

# download missing source htmls
targets = getDownloadList fromId, toId
console.log "number of files to be downloaded:" targets.length
targets.map(syncCurlHTML)

# parse downloaded files to update data structure 'gazettes' and 'index'
ids.forEach (id) ->
    parseHTML gazettes, index, id, "#srcDir/#id.html"

# compare data structure 'gazettes' and 'index' , if any entry of 'index' has no attribute 'files',
# get links of files by getFileList and update 'index'
processors = []
for id, g of gazettes when !ids? || id in ids => let id, g
    for i, _which in index when i.gazette ~= id and !i.files? => let i
        return if index[_which].files # skip processed entry
        console.log "To get file link for:" id, i.book, i.seq
        processors.push (mkWrapper index, _which, {g.year, g.vol, i.book, i.seq}, id, \doc)
console.log "How many entries of gazettes need file link: " processors.length

(err, result) <- Async.parallel processors
# save updated data structure back to json
fs.writeFileSync \data/gazettes.json JSON.stringify gazettes, null, 4
fs.writeFileSync \data/index.json JSON.stringify index, null, 4

console.log \done

