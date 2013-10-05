# Maintain the 'files' attribute of each entries of data/index.json.
#
# $ lsc prepare-source.ls
#

require! {Async: \async, fs, request, mkdirp, optimist, index: \./data/index, gazettes: \./data/gazettes}


# Get array of static links that refer to communique files.
# specify id, year, vol... to build a URL of a web page, then parse the content.
# then we got links such as
#
#     http://lci.ly.gov.tw/LyLCEW/communique/work/89/50/LCIDC01_895001_00001.doc
#
getFileList = ({year, vol, book, seq}, id, type, cb) ->
    err, res, body <- request do
        method: 'POST'
        uri: 'http://lci.ly.gov.tw/LyLCEW/dwr/call/plaincall/Lci2tCommFileAttachDWR.query.dwr'
        headers: do
            Origin: 'http://lci.ly.gov.tw'
            Referer: 'http://lci.ly.gov.tw/LyLCEW/lcivCommMore.action'
            User-Agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.17 (KHTML, like Gecko) Chrome/24.0.1312.5 Safari/537.17'
        form: do
            callCount: 1
            windowName: ''
            'c0-scriptName': 'Lci2tCommFileAttachDWR'
            'c0-methodName': 'query'
            'c0-id': '0'
            'c0-param0': "string:#{year}"
            'c0-param1': "string:#{vol}"
            'c0-param2': "string:#{book}"
            'c0-param3': "string:#{seq}"
            'c0-param4': 'null:null'
            'c0-param5': 'string:' + if type is \html => 4 else 2
            'c0-param6': 'null:null'
            batchId: 3
            instanceId: 0
            page: '/LyLCEW/lcivCommMore.action'
            scriptSessionId: 'G2QK8XSngQBcD1FnDRSQj3XmZHj/VlFd*Hj-A9LrEZ7og'
    [_, entry] = body.match /r.handleCallback\((.*)\);/
    [_, _, entry]? = try eval "[#{entry}]" # XXX: sandbox
    cb (for {filePath},i in entry
        uri = switch type
        | \html => 'http://lci.ly.gov.tw/LyLCEW/jsp/ldad000.jsp?irKey=&htmlType=communique&fileName='
        else 'http://lci.ly.gov.tw/LyLCEW/'
        uri + filePath.replace /\\/g, '/'
    )

{gazette} = optimist.argv

# make a function object that could be invoked by Async.parallel
mkWrapper = (indexJson, which, dataObj, id, type) ->
    return (cb) ->
        # update index.json object if retrieved file link
        indexJson[which].files <- getFileList dataObj, id, type
        console.log \got which, id, indexJson[which].files
        cb!

# compare gazettes.json and index.json, if any entry of index.json has no attribute 'files',
# get links of files by getFileList and update index.json
processors = []
for id, g of gazettes when !gazette? || id ~= gazette => let id, g
    for i, _which in index when i.gazette ~= id and !i.files? => let i
        return if index[_which].files # skip processed entry
        console.log "To get file link for:" id, i.book, i.seq
        processors.push (mkWrapper index, _which, {g.year, g.vol, i.book, i.seq}, id, \doc)

console.log "How many entries of gazettes need file link: " processors.length
(err, result) <- Async.parallel processors
fs.writeFileSync \data/index.json JSON.stringify index, null, 4
