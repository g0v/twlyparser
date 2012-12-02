require! \./lib/ly
require! <[request optimist path fs shelljs async]>

{Parser} = require \./lib/parser

{gazette, dometa, ad, lodev} = optimist.argv


metaOnly = dometa
skip = false
funcs = []
ly.forGazette gazette, (id, g, type, entries, files) ->
    return if g.sitting if dometa
    return if ad and g.ad !~= ad
    return if type isnt /院會紀錄/
    files = [files.0] if metaOnly
    files.forEach (uri) -> funcs.push (done) ->
        fname = path.basename uri
        file = "source/#{id}/#{fname}"
        _, {size}? <- fs.stat file
        return done! unless size
        html = file.replace /\.doc$/, '.html'

        extractMeta = ->
            return done! unless dometa
            meta = null
            parser = new Parser do
                output: ->
                output-json: -> meta := it
            try
                parser.parseHtml fs.readFileSync html, \utf8
            catch err
                console.log \err err
            if meta?ad
                g <<< meta{ad,session,sitting,extra}
                console.log id, g
            else
                console.log \noemta, id
            done!

        _, {size}? <- fs.stat html
        return extractMeta! if size
        console.log \doing file
        # XXX: correct this for different OS
        cmd = if lodev
            "/Applications/LOdev.app/Contents/MacOS/python unoconv/unoconv.p3 -f html #file"
        else
            "/Applications/LibreOffice.app/Contents/MacOS/python unoconv/unoconv  -f html #file"
        p = shelljs.exec cmd, (code, output) ->
            console.log \converted output, code, p?
            clear-timeout rv
            extractMeta! if p?
        rv = do
            <- setTimeout _, 120sec * 1000ms
            console.log \timeout
            p.kill \SIGTERM
            p := null
            done!

err, res <- async.waterfall funcs
console.log \ok, res
if metaOnly
    fs.writeFileSync \data/gazettes.json JSON.stringify ly.gazettes, null, 4
