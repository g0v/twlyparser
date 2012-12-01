require! \./lib/ly
require! <[request optimist path fs sh async]>

# XXX change to use parser directly

{ad} = optimist.argv

metaOnly = false
funcs = []
ly.forGazette null (id, g, type, entries, files) ->
    return if ad and g.ad !~= ad
    return if type isnt /院會紀錄/
    funcs.push (done) ->
        console.log id
        cmd = sh "lsc ./format-log.ls --gazette #id"
        cmd.file "examples/#id.md"
        output <- cmd.err.result
        console.log id, output
        done!

err, res <- async.waterfall funcs
console.log \ok, res
