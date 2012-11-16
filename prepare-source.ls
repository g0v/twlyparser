require! {fs, request, q, mkdirp, optimist, index: \./data/index, gazettes: \./data/gazettes}


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

defers = []
for id, g of gazettes when !gazette? || id ~= gazette => let id, g
    x = q.defer!
    defers.push x.promise
    gdefers = []
    err <- mkdirp "source/#{id}"
    throw err if err
    for i,_which in index when i.gazette ~= id and !i.files? => let i, d = q.defer!
        console.log id, i.book, i.seq
        gdefers.push d.promise
        index[_which].files <- getFileList {g.year, g.vol, i.book, i.seq}, id, \doc
        d.resolve!
    <- q.allResolved gdefers
    .then
    x.resolve!

<- q.allResolved defers
.then
fs.writeFileSync \data/index-files.json JSON.stringify index, null, 4



#    all = defers.map(-> it.valueOf!).reduce (+++)
#    files = {[file, true] for file in all}
#    for f of files
#        console.log f
#        console.log uri
#        request {method: \GET, uri}
#        .pipe fs.createWriteStream "source/#{id}/#id-#{i.book}-#{i.seq}-#i.#type"

