require! {optimist, fs, path}
require! \./lib/ly
{Parser} = require \./lib/parser

{gazette, ad, dir = '.'} = optimist.argv

fixup = ->
    it  .replace /\uE58E/g, '冲'
        .replace /\uE8E2/g, '堃'
        .replace /\uE8E4/g, '崐'
        .replace /\uE1BD/g, '%'

ly.forGazette gazette, (id, g, type, entries, files) ->
    return if type isnt /院會紀錄/
    return if ad and g.ad !~= ad

    console.log id
    output = fs.createWriteStream "#dir/#id.md"
    parser = new Parser output: (...args) -> output.write (args +++ "\n")join ''
    for uri in files => let fname = path.basename uri
        file = "source/#{id}/#{fname}".replace /\.doc$/, '.html'
        parser.parseHtml fixup fs.readFileSync file, \utf8
    parser.store!
    output.end!
