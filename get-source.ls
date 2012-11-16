require! {index: \./data/index-files, request, q, mkdirp, optimist, path, fs, gazettes: \./data/gazettes}

{gazette} = optimist.argv

for id, g of gazettes when !gazette? || id ~= gazette => let id, g
    entries = [i for i in index when i.gazette ~= id]
    bytype = {}
    for {type}:i in entries
        (bytype[type] ||= []).push i
    for type, entries of bytype when type is /院會紀錄/
        console.log type
        allfiles = entries.map (.files) .reduce (+++)
        for uri of {[x,true] for x in allfiles} => let fname = path.basename uri
            file = "source/#{id}/#{fname}"
            fetchit = (cb) ->
                request {method: \GET, uri} .pipe fs.createWriteStream file
            _, {size}? <- fs.stat file
            return if size?
            <- fetchit
            console.log \done id
#    err <- mkdirp "source/#{id}"
        
#        gdefers.push d.promise
#        index[_which].files <- getFileList {g.year, g.vol, i.book, i.seq}, id, \doc
#        d.resolve!
#    <- q.allResolved gdefers
#    .then
#    x.resolve!

#<- q.allResolved defers
#.then
#fs.writeFileSync \data/index-files.json JSON.stringify index, null, 4



#    all = defers.map(-> it.valueOf!).reduce (+++)
#    files = {[file, true] for file in all}
#    for f of files
#        console.log f
#        console.log uri

