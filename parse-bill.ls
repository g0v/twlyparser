
require! \./lib/ly
require! <[optimist path fs ./lib/util]>
{BillParser} = require \./lib/parser

id = optimist.argv._

file = "source/bill/#{id}/file.html"

parser = new BillParser {-chute}
content = []
bill = require "./source/bill/#{id}/index.json"
parser.output-json = -> content.push it
parser.output = (line) -> match line
| /^案由：(.*)$/ => bill.abstract = that.1
| otherwise =>
parser.base = "source/bill/#{id}"

parser.parseHtml util.readFileSync file

console.log JSON.stringify bill <<< {content}, null 4
