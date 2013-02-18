require! {fs, request, Q: \q, mkdirp, optimist, index: \./data/index, gazettes: \./data/gazettes}


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

cnt = 0;
funcs = for id, g of gazettes when !gazette? || id ~= gazette => let id, g
    ->
        gdefers = []
        for i,_which in index when i.gazette ~= id and !i.files? => let i, d = Q.defer!
            return if index[_which].files
            console.log id, i.book, i.seq
            gdefers.push d.promise
            index[_which].files <- getFileList {g.year, g.vol, i.book, i.seq}, id, \doc
            console.log \got _which, id, i.book, i.seq
            d.resolve!
        Q.allResolved gdefers

res = funcs.reduce ((soFar, f) -> soFar.then f), Q.resolve!

<- res.then
fs.writeFileSync \data/index.json JSON.stringify index, null, 4
