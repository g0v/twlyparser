require! {optimist, fs, path}
require! \./lib/ly
{Parser} = require \./lib/parser

{gazette} = optimist.argv
fixup = ->
    it.replace /\uE58E/g, '冲'
        .replace /\uE8E2/g, '堃'
        .replace /\uE1BD/g, '%'

parser = new Parser
ly.forGazette gazette, (id, g, type, entries, files) ->
    return if g.sitting
    return if type isnt /院會紀錄/
    for uri in files => let fname = path.basename uri
        file = "source/#{id}/#{fname}".replace /\.doc$/, '.html'
        parser.parseHtml fixup fs.readFileSync file, \utf8

parser.store!
