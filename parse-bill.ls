require! \./lib/ly
require! <[optimist path fs ./lib/util]>
{BillParser} = require \./lib/parser

{dir} = optimist.argv
dir ?= ly.misq.cache_dir
id = optimist.argv._

cb = -> throw it

doit = ->
    parser = new BillParser {-chute}
    content = []
    bill = require "#dir/bills/#{id}/index.json"
    parser.output-json = -> content.push it
    parser.output = (line) -> match line
    | /^案由：(.*)$/ => bill.abstract = that.1
    | /^提案編號：(.*)$/ => bill.reference = that.1
    | /^議案編號：(.*)$/ => bill.id = that.1
    | otherwise =>
    parser.base = "#dir/bills/#{id}"

    parser.parseHtml util.readFileSync file
    console.log JSON.stringify bill <<< {content}, null 4

file = "#dir/bills/#{id}/file.html"

_, {size}? <- fs.stat file
return doit! if size

util.convertDoc file.replace(/html$/, \doc), do
    lodev: true
    error: -> cb null
    success: doit

