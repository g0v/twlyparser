require! \./lib/ly
require! <[request q mkdirp optimist path fs]>

{gazette} = optimist.argv

id, g, type, entries, allfiles <- ly.forGazette gazette
err <- mkdirp "source/#{id}"
throw err if err
for uri in allfiles => let uri, fname = path.basename uri
    file = "source/#{id}/#{fname}"
    fetchit = (cb) ->
        writer = with fs.createWriteStream file
            ..on \error -> throw it
            ..on \close cb
            ..
        request {method: \GET, uri} .pipe writer
    _, {size}? <- fs.stat file
    return if size?
    <- fetchit
    console.log \done id, uri
