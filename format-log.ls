require! {optimist, fs, path}
require! \./lib/util
require! \./lib/ly
{Parser} = require \./lib/parser

{gazette, ad, dir = '.'} = optimist.argv

ly.forGazette gazette, (id, g, type, entries, files) ->
    return if type isnt /院會紀錄/
    return if ad and g.ad !~= ad

    console.log id
    output = fs.createWriteStream "#dir/#id.md"
    parser = new Parser output: (...args) -> output.write (args +++ "\n")join ''
    for uri in files => let fname = path.basename uri
        file = "source/#{id}/#{fname}".replace /\.doc$/, '.html'
        parser.parseHtml util.readFileSync file
    parser.store!
    output.end!
