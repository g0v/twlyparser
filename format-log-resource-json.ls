/* extract resource data from markdown to json */
require! {path}
require! \./lib/util
{Parser, ResourceParser} = require \./lib/parser

parser = new ResourceParser
parser.parseMarkdown util.readFileSync "data/4004.md"
parser.store!
