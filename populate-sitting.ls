require! \./lib/ly
require! <[request optimist path fs shelljs async]>

{Parser, MemoParser} = require \./lib/parser

{gazette, dometa, ad, lodev, type, force} = optimist.argv


metaOnly = dometa
skip = false
funcs = []
memo = true if type is \memo

index-type = switch type
| \memo => \議事錄
| \committee => \委員會紀錄
else \院會紀錄

ly.forGazette gazette, (id, g, type, entries, files) ->
    unless force
        if memo
            return if entries.0.sitting
        else
            return if g.sitting
    return if ad and g.ad !~= ad
    return if type isnt index-type
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
            klass = if memo => MemoParser else Parser
            parser = new klass do
                output: ->
                output-json: -> meta := it
            try
                parser.parseHtml fs.readFileSync html, \utf8
            catch err
                console.log \err err.stack
            if meta?ad
                if memo
                    entries.0 <<< meta{ad,session,sitting,extra,secret}
                else
                    g <<< meta{ad,session,sitting,extra,secret}
                console.log id, g
            else
                console.log \noemta, id, html
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
            <- setTimeout _, 320sec * 1000ms
            console.log \timeout
            p.kill \SIGTERM
            p := null
            done!

err, res <- async.waterfall funcs
console.log \ok, res
if metaOnly
    fs.writeFileSync \data/gazettes.json JSON.stringify ly.gazettes, null, 4
    fs.writeFileSync \data/index.json JSON.stringify ly.index, null, 4
