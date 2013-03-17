require! \./lib/ly
require! <[request optimist path fs shelljs async]>

{YSLogParser, HTMLParser, MemoParser} = require \./lib/parser
{convertDoc} = require \./lib/util

{gazette, dometa, ad, type, force} = optimist.argv


metaOnly = dometa
skip = false
funcs = []
memo = true if type is \memo

if dometa
    {Rules} = require \./lib/rules
    rules = new Rules \patterns.yml

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
    if ad is \empty
        return unless g.sitting?
    else
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
            klass = if memo => MemoParser else class extends YSLogParser implements HTMLParser
            parser = new klass do
                rules: rules
                output: ->
                output-json: -> meta := it
            try
                parser.parseHtml fs.readFileSync html, \utf8
                parser.store!
            catch err
                console.log \err err.stack
            if meta?ad?
                if memo
                    entries.0 <<< meta{ad,session,sitting,extra,secret,preparatory}
                else
                    g <<< meta{ad,session,sitting,extra,secret,preparatory}
                console.log id, g
            else
                console.log \noemta, id, html
            done!

        _, {size}? <- fs.stat html
        return extractMeta! if size
        console.log \doing file
        convertDoc file, {error: done, success: -> extractMeta!}

err, res <- async.waterfall funcs
console.log \ok, res
if metaOnly
    fs.writeFileSync \data/gazettes.json JSON.stringify ly.gazettes, null, 4
    fs.writeFileSync \data/index.json JSON.stringify ly.index, null, 4
