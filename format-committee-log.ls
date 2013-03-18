require! {optimist, fs, path, mkdirp}
require! \./lib/util
require! \./lib/ly
require! \./lib/rules
{CommitteeLogParser, HTMLParser, TextParser, TextFormatter} = require \./lib/parser

{gazette, ad, session, dir = '.', text, fromtext, only-committee} = optimist.argv

rules = new rules.Rules \patterns.yml

fname = ({ad, session, committee, sitting}) ->
    "#ad/#session/#{ committee.join \- }/#sitting"

parseContent = (id, g, klass, ext, e) ->
    var current-file, output
    warned = 0
    parser = new klass do
        rules: rules
        context-cb: ->
            fs.closeSync output if output
            unless e.summary.match new RegExp util.committees[it.committee.0]
                output := null
                console.log e.summary, \notfound
                return
            e <<< it
            warned := 0
            current-file = "#dir/#{fname it}.#ext"
            mkdirp.sync path.dirname current-file
            console.error \=== current-file
            output := fs.openSync current-file, \w

        output: (...args) ->
            unless output
                console.error \unhandled id, args unless warned++
                return
            fs.writeSync output, (args ++ "\n")join ''

    if fromtext
        file = "#dir/#{fname e}.txt"
        output = fs.openSync (file.replace /.txt$/, '.md'), \w
        parser.parseText fs.readFileSync file
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
    for {summary}:e in entries
        if ad is \empty
            continue if e.sitting?
        else
            continue if ad and e.ad !~= ad

        if session
            continue if e.session !~= session

        unless [_, committee, multi, type]? = summary.match /^(.*?)(?:兩|三)?委員會(聯席)?(會議|公聽會)/
            console.error id, summary
            continue
        if type is \公聽會
            console.error \skipping summary
            continue
        committee .= replace /與/g, \及
        klass = switch
        | text     => TextFormatter
        | fromtext => class extends CommitteeLogParser implements TextParser
        else       => class extends CommitteeLogParser implements HTMLParser
        ext   = if text => \txt else \md
        if only-committee and only-committee isnt (e.committee ? []).join \-
            continue

        #console.log \=== e.files
        try
            parseContent id, g, klass, ext, e
        catch err
            console.error \ERROR id, e, err
console.log '\n'

fs.writeFileSync \data/index.json JSON.stringify ly.index, null, 4
