require! \./lib/ly
require! <[request optimist path fs sh async]>

metaOnly = false
funcs = []
ly.forGazette null (id, g, type, entries, files) ->
    return if g.sitting
    return if type isnt /院會紀錄/
    files = [files.0] if metaOnly
    files.forEach (uri) -> funcs.push (done) ->
        fname = path.basename uri
        file = "source/#{id}/#{fname}"
        _, {size}? <- fs.stat file
        return done! unless size

        html = file.replace /\.doc$/, '.html'
        _, {size}? <- fs.stat html
        return done! if size
        console.log \doing file
        output <- sh "/Applications/LibreOffice.app/Contents/MacOS/python unoconv/unoconv  -f html #file" .result
        console.log \converted output
        done!

err, res <- async.waterfall funcs
console.log \ok, res
