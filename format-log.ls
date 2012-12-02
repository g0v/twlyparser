require! {optimist, fs, path}
require! \./lib/util
require! \./lib/ly
{Parser, TextFormatter} = require \./lib/parser

{gazette, ad, dir = '.', text} = optimist.argv

ly.forGazette gazette, (id, g, type, entries, files) ->
    return if type isnt /院會紀錄/
    return if ad and g.ad !~= ad

    console.log id

    klass = if text => TextFormatter else Parser
    ext   = if text => \txt else \md
    output = fs.openSync "#dir/#id.#ext" \w
    try
        parser = new klass output: (...args) -> fs.writeSync output, (args +++ "\n")join ''
        for uri in files => let fname = path.basename uri
            file = "source/#{id}/#{fname}".replace /\.doc$/, '.html'
            parser.parseHtml util.readFileSync file
        parser.store! if parser.store?
        fs.closeSync output
    catch err
        console.log \err err.stack
