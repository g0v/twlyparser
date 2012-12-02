/* extract resource data from markdown to json */
require! {path, fs}
require! \./lib/util
{Parser, ResourceParser} = require \./lib/parser

output = fs.openSync "data/4004_interp.json" \w
parser = new ResourceParser output: (...args) -> fs.writeSync output, (args +++ "\n")join ''
parser.parseMarkdown util.readFileSync "data/4004.md"
parser.store!
fs.closeSync output

#console.log util.build_people_interp_map \4004, parser.results, {}
