require! \./lib/ly
require! <[request q mkdirp optimist path fs async]>

{gazette} = optimist.argv

funcs = []
do
    id, g, type, entries, allfiles <- ly.forGazette gazette
    funcs.push (cb) ->
        err <- mkdirp "source/#{id}"
        throw err if err
        cb!

    for uri in allfiles => let uri, fname = path.basename uri
        file = "source/#{id}/#{fname}"
        funcs.push (cb) ->
            _, {size}? <- fs.stat file
            return cb! if size?

            console.log \getting file
            writer = with fs.createWriteStream file
                ..on \error -> throw it
                ..on \close ->
                    <- setTimeout _, 1000ms
                    console.log \done file
                    cb!
                ..
            request {method: \GET, uri} .pipe writer


err, res <- async.waterfall funcs
console.log \done, res
