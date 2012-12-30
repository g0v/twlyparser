
require! \./lib/ly
require! <[optimist path fs ./lib/util]>
{BillParser} = require \./lib/parser

id = optimist.argv._

file = "source/bill/#{id}/file.html"

parser = new BillParser
parser.output-json = -> console.log JSON.stringify it, null 4
parser.output = ->
parser.base = "source/bill/#{id}"

parser.parseHtml util.readFileSync file
