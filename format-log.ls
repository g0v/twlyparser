require! {optimist, fs}
{Parser} = require \./lib/parser

{id, _} = optimist.argv
fixup = ->
    it.replace /\uE58E/g, '冲'

parser = new Parser
for file in _
    parser.parseHtml fixup fs.readFileSync file, \utf8
parser.store!
