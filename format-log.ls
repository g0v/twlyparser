require! {optimist, fs, path}
require! \./lib/util
require! \./lib/ly
require! \./lib/rules
{YSLogParser, HTMLParser, TextParser, TextFormatter} = require \./lib/parser

{gazette, ad, session, dir = '.', text, fromtext} = optimist.argv

rules = new rules.Rules \patterns.yml

ly.forGazette gazette, (id, g, type, entries, files) ->
    return if type isnt /院會紀錄/
    if ad is \empty
        return if g.sitting?
    else
        return if ad and g.ad !~= ad

    return if session and g.session !~= session

    klass = switch
    | text     => TextFormatter
    | fromtext => class extends YSLogParser implements TextParser
    else       => class extends YSLogParser implements HTMLParser
    ext   = if text => \txt else \md
    output = fs.openSync "#dir/#id.#ext" \w
    process.stdout.write id
    process.stdout.write '\r'

    try
        parser = new klass {rules: rules, output: (...args) -> fs.writeSync output, (args ++ "\n")join ''}

        if fromtext
            file = "#dir/#id.txt"
            parser.parseText fs.readFileSync file
        else
            parser.base = "source/#{id}"
            for uri in files => let fname = path.basename uri
                file = "source/#{id}/#{fname}".replace /\.doc$/, '.html'
                parser.parseHtml util.readFileSync file
        parser.store! if parser.store?
        fs.closeSync output
    catch err
        console.log \err id, err.stack

console.log '\n'
