require! {index: \./data/index-files, request, q, mkdirp, optimist, path, fs, gazettes: \./data/gazettes}

{gazette} = optimist.argv

for id, g of gazettes when !gazette? || id ~= gazette => let id, g
    err <- mkdirp "source/#{id}"
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
