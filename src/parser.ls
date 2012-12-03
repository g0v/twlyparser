require! {cheerio, marked}
require! "../lib/util"

# ad (appointed dates) (屆別)
# session (會期)
# sitting (會次)
class Meta
    ({@output, @output-json} = {}) ->
        @output "# 院會紀錄\n\n"
        @meta = {}
    push-line: (speaker, text) ->
        if speaker 
            @serialize!
            return 
        if @ctx is \speaker
            [_, position, name] = text.match /^(?:(.+)\s+)?(.*)$/
            return @

        match text
        | /立法院第(\S+)屆第(\S+)會期第(\S+?)次(?:臨時會第(\S+)次)?會議紀錄/ =>
            @meta<[ad session sitting]> = that[1 to 3].map -> util.intOfZHNumber it
            if it = that[4]
                @meta.extra = util.intOfZHNumber it
        | /主\s*席\s+(.*)$/ =>
            @ctx = \speaker
            @meta.speaker = that.1
        | /時\s*間\s+中華民國(\S+)年(\S+)月(\S+)日（(\S+)）(\S+?)(\d+)時/ =>
            @meta.datetime = util.datetimeOfLyDateTime that[1 to 3] [5 to 6]
        @output "#text\n"
        return @
    serialize: ->
        @output-json @meta if @output-json
        @output "```json\n", JSON.stringify @meta, null, 4b
        @output "\n```\n\n"

class Announcement
    ({@output = console.log} = {}) ->
        @output "## 報告事項\n\n"
        @items = {}
        @last-item = null
        @i = 0
    push-line: (speaker, text, fulltext) ->
        if [_, item, content]? = text.match util.zhreg
            item = util.parseZHNumber item
            text = content

            match text
            | /(\S+委員會)/
                console.log 
            @i++
            @output "#{@i}. #text\n"
            @last-item = @items[item] = {subject: content, conversation: []}
        else
            @output "    #fulltext\n"
            @last-item.conversation.push [speaker, text]
        return @
    serialize: ->

class Discussion
    ({@output} = {}) ->
        @output "## 討論事項\n\n"
        @lines = []
    push-line: (speaker, text, fulltext) ->
        @output "#fulltext\n"
        return @
    serialize: ->

class Consultation
    ({@output} = {}) ->
        @output "## 黨團協商結論\n\n"
        @lines = []
    push-line: (speaker, text, fulltext) ->
        @output "#fulltext\n"
        return @
    serialize: ->

class Proposal
    ({@output} = {}) ->
        @output "## 黨團提案\n\n"
        @lines = []
    push-line: (speaker, text, fulltext) ->
        @output "#fulltext\n"
        return @
    serialize: ->


class Interpellation
    ({@output} = {}) ->
        @current-conversation = []
        @current-participants = []
        @conversation = []
        @subsection = false
        @document = false
    flush: ->
        type = switch
        | @exmotion => 'exmotion'
        | @document => 'interpdoc'
        else 'interp'
        if @current-conversation.length
            if @subsection
                people = if type is 'interp' => @current-participants else null
                meta = {type, people}
                @output "    ```json\n    #{ JSON.stringify meta }\n    ```"
                itemprefix 
                for [speaker, fulltext] in @current-conversation
                    itemprefix = if type is 'interp'
                        if speaker => '* ' else '    '
                    else
                        ''
                    @output "    #itemprefix#fulltext\n"
                @conversation.push [ type, @current-conversation ]
            else
                for [speaker, fulltext] in @current-conversation => @output "* #fulltext\n"
                @conversation = @conversation +++ @current-conversation
        @current-conversation = []
        @current-participants = []
        @exmotion = false
        @subsection = true

    push-rich: (html) ->
        @current-conversation.push [ null, html ]
    push-line: (speaker, text, fulltext) ->
        if (speaker ? @lastSpeaker) is \主席 and text is /報告院會|詢答時間|已質詢完畢|處理完畢|提書面質詢/
            @flush!
            @output "* #fulltext\n"
            @conversation.push [speaker, text]
            @document = text is /提書面質詢/
        else if !speaker? && @current-conversation.length is 0
            @conversation.push [speaker, text] # meeting actions
            @output "* #fulltext\n"
        else
            [_, h, m, text]? = text.match /^(?:\(|（)(\d+)時(\d+)分(?:\)|）)(.*)$/, ''
            entry = [speaker, text]
            #@output "* [#h, #m]\n" if h?
            @current-conversation.push [speaker, fulltext]
            if speaker => @current-participants.push speaker unless speaker in @current-participants
        if speaker is \主席 and text is /現在.*處理臨時提案/
            @exmotion = true

        @lastSpeaker = speaker if speaker
        @
    serialize: -> @flush!

class Questioning
    ({@output} = {}) ->
        @output "## 質詢事項\n\n"
        @ctx = null
        @reply = {}
        @question = {}
    push: (speaker, text, fulltext) ->
        if [_, item, content]? = text.match util.zhreg
            item = util.parseZHNumber item

        if item
            @ctx ?= \question if content is /^本院/
            @[@ctx][item] = [speaker, text]
            @output "#item. #content"
        else
            @output "#fulltext\n"

    push-line: (speaker, text, fulltext) ->
        match text
        | /行政院答復部分$/ =>
            @output "\n" + '### 行政院答復部分' + "\n"
            @ctx = \reply
        | /本院委員質詢部分$/ =>
            @output "\n" + '### 本院委員質詢部分' + "\n"
            @ctx = \question
        | otherwise => @push speaker, text, fulltext
        return @
    serialize: ->

HTMLParser = do
    parse: (node) ->
        self = @
        cleanup = (node) ~>
            text = @$(node)text! - /^\s+|\s+$/g
            text.=replace /\s*\n+\s*/g, ' '
            text

        match node.0.name
        | /multicol|div|center|dd|dl|ol|ul|li/ => node.children!each -> self.parse @
        | \h1 =>
            @parseLine cleanup node
        | \h2 =>
            @parseLine cleanup node
        | \table => @parseRich node
        | \p     =>
            text = cleanup node
            return unless text.length
            return unless text is /\D/
            @parseLine text
        else => console.error \unhandled: node.0.name, node.html!
    parseHtml: (data) ->
        self = @
        @$ = cheerio.load data, { +lowerCaseTags }
        @$('body').children!each -> self.parse @

class Parser implements HTMLParser
    ({@output = console.log, @output-json, @metaOnly} = {}) ->
        @lastSpeaker = null
        @ctx = @newContext Meta
    store: ->
        @ctx.serialize! if @ctx

    newContext: (ctxType) ->
        @store!
        @ctx := if ctxType? => new ctxType {@output, @output-json} else null

    parseLine: (fulltext) ->
        text = fulltext
        [full, speaker, content]? = text.match /^([^：]{2,10})：(.*)$/
        if speaker
            if speaker is /以下|本案決議/
                text = full
                speaker = null
            else
                text = content

        if text is /報告院會/ and text is /現在散會/
            @store!
            @ctx := null

        if text is /^報\s*告\s*事\s*項$/
            @newContext Announcement
        else if text is /^質\s*詢\s*事\s*項$/
            @newContext Questioning
            @lastSpeaker = null
        else if text is /^討\s*論\s*事\s*項$/
            @newContext Discussion
        else if (speaker ? @lastSpeaker) is \主席 && text is /處理.*黨團.*提案/
            @newContext Proposal
            @output "#fulltext\n\n"
        else if (speaker ? @lastSpeaker) is \主席 && text is /處理.*黨團.*協商結論/
            @newContext Consultation
            @output "#fulltext\n\n"
        else if (speaker ? @lastSpeaker) is \主席 && text is /對行政院.*質詢/
            @newContext Interpellation
            @ctx .=push-line speaker, text, fulltext
        else if (speaker ? @lastSpeaker) is \主席 && text is /處理.*復議案/
            @output "## 復議案\n\n"
            @newContext null
        else
            if @ctx
                @ctx .=push-line speaker, text, fulltext
            else
                @output "#fulltext\n\n"
        @lastSpeaker = speaker if speaker

    parseRich: (node) ->
        rich = @$ '<div/>' .append node
        rich.find('img').each -> @.attr \SRC, ''
        if @ctx?push-rich
            @ctx.push-rich rich.html!
        else
            @output "    ", rich.html!, "\n"

class TextParser extends Parser
    parseText: (data) ->
        for line in data / "\n"
            if line.0 is \<
                if @ctx?push-rich
                    @ctx.push-rich line
                else
                    @output line, "\n"
            else
                @parseLine line

class TextFormatter implements HTMLParser
    ({@output = console.log} = {}) ->

    parseLine: ->
        if it.0 is \<
            it-= /^<|>/g
        @output it

    parseRich: (node) ->
        require! {exec-sync: \exec-sync, fs}
        rich = @$ '<div/>' .append node
        self = @
        convert = []
        rich.find('img').each ->
            src = @attr \SRC
            file = self.base + '/' + src
            [_, ext] = src.match /\.(\w+)$/
            output = exec-sync "imgsize #file"
            [_, width, height] = output.match /width="(\d+)" height="(\d+)"/
            if width / height > 100
                @replaceWith('<hr /')
            else
                @attr \SRC "data:image/#ext;base64,"+(fs.readFileSync file)toString \base64

        @output rich.html! - /^\s+/mg - /\n/g - /position: absolute;/g

metaOfToken = (token) ->
    if token.type is \code and token.lang is \json
        JSON.parse token.text

class ItemList

    ({}) ->
        @meta = null
        @ctx = null
        @results = []
        @output = console.log

    parseToken: (token) ->
        meta = metaOfToken token
        if meta and meta.type is \interp
            @meta = meta

        if token.type is \list_item_start
            @ctx = \item
            return

        if @ctx = \item and token.type is \text
                @results.push @parseConversation token.text

        if token.type is \list_item_end
            @ctx = null
            return

    parseConversation: (text) ->
        match text 
        | /^(\S+?)：\s*(.*)/ => 
            [speaker, content] = that[1 to 2]
            @lastSpeaker = speaker
        else
            speaker = if @lastSpeaker
                    then @lastSpeaker
                    else \主席
            content = text
        {speaker:speaker, content:content}
        
class Text

    ({}) ->
        @meta = null
        @ctx = null
        @results = []

    parseToken: (token) ->
        meta = metaOfToken token
        if meta and meta.type is \interpdoc
            @meta = meta

        if token.type is \space
            @results.push "\n"
        
        if token.type is \text
            @results.push token.text

class ResourceParser

    ({@output = console.log} = {}) ->
        @ctx = null

    parseMarkdown: (data) ->
        marked.setOptions \ 
            {gfm: true, pedantic: false, sanitize: true}
        @tokens = marked.lexer data
        @parse @tokens
   
    parse: (tokens) -> 
        @results = []
        for token in tokens

            if token.text is /.*詢答時間為.*/
                @newContext ItemList

            if token.text is /.*以書面答復.*?並列入紀錄.*?刊登公報.*/
                @newContext Text


            if @ctx
                @ctx.parseToken token

    newContext: (ctxType) ->
        @results.push [@ctx.meta, @ctx.results] if @ctx
        @ctx = if ctxType
            then new ctxType
            else null
           
    store: ->
        @output JSON.stringify @results, null, 4b

module.exports = { Parser, TextParser, TextFormatter, ResourceParser }
