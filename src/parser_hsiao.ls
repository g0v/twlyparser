require! {cheerio, marked, path, crypto}
require! \js-yaml
require! "../lib/util"
require! "../lib/rules"
require! "../lib/parser"

class MemoParser implements parser.HTMLParser
    ({@output = console.log, @output-json, @metaOnly, @rules} = {}) ->
        @lastSpeaker = null
        @ctx = @newContext Meta
    store: ->
        @ctx.serialize! if @ctx

    newContext: (ctxType, args = {}) ->
        @store!
        @ctx := if ctxType? => new ctxType args <<< {@output, @rules, @output-json} else null

    parseLine: (fulltext) ->
        if fulltext is \報告事項
            @newContext null
        if @ctx
            @ctx .=push-line null, fulltext, fulltext
        else
            @output "#fulltext\n\n"

    parseRich: (node) ->
        rich = @$ '<div/>' .append node
        rich.find('img').each -> @.attr \SRC, ''
        if @ctx?push-rich
            @ctx.push-rich rich.html!
        else
            @output "    ", rich.html!, "\n"

module.exports = { MemoParser }
