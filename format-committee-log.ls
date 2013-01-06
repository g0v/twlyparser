require! {optimist, fs, path, mkdirp}
require! \./lib/util
require! \./lib/ly
require! \./lib/rules
{Parser, TextParser, TextFormatter} = require \./lib/parser

{gazette, ad, dir = '.', text, fromtext} = optimist.argv

rules = new rules.Rules \patterns.yml

fname = ({ad, session, committee, sitting}) ->
    "#ad/#session/#{ committee.join \- }/#sitting"

parseContent = (id, g, klass, ext, e) ->
    var current-file, output
    parser = new klass do
        rules: rules
        context-cb: ->
            e <<< it
            current-file = "#dir/#{fname it}.txt"
            mkdirp.sync path.dirname current-file
            console.error \=== current-file
            fs.closeSync output if output
            output := fs.openSync current-file, \w

        output: (...args) ->
            unless output
                console.error args
                return
            fs.writeSync output, (args +++ "\n")join ''

    if fromtext
        file = "#dir/#id.txt"
        parser.parseText util.readFileSync file
    else
        parser.base = "source/#{id}"
        for uri in e.files => let fname = path.basename uri
            file = "source/#{id}/#{fname}".replace /\.doc$/, '.html'
            parser.parseHtml util.readFileSync file
    parser.store?!
    unless output
        console.error \nooutput
    fs.closeSync output if output


ly.forGazette {gazette, ad, type: \委員會紀錄} (id, g, type, entries, files) ->
    return if id < 3943
    if ad is \empty
        return if g.sitting?
    else
        return if ad and g.ad !~= ad

    for {summary}:e in entries
        unless [_, committee, multi, type]? = summary.match /^(.*?)(?:兩|三)?委員會(聯席)?(會議|公聽會)/
            console.error id, summary
            continue
        committee .= replace /與/g, \及
        console.log id, util.parseCommittee committee
        klass = if text => TextFormatter else if fromtext => TextParser else Parser
        ext   = if text => \txt else \md

        console.log \=== e.files
        try
            parseContent id, g, klass, ext, e
        catch err
            console.error \ERROR err
console.log '\n'

fs.writeFileSync \data/index.json JSON.stringify ly.index, null, 4
