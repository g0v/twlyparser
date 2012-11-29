require! {cheerio, optimist, fs, request}
{Parser} = require \./lib/parser

{id, _} = optimist.argv
fixup = ->
    it.replace /\uE58E/g, '冲'

parser = new Parser
for file in _
    data = fixup fs.readFileSync file, \utf8
    $ = cheerio.load data, { +lowerCaseTags }
    $('body').children!each -> parser.parse @
parser.store!
