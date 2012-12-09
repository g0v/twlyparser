require! {cheerio, marked, path}
require! \js-yaml
require! "../lib/util"
require! "../lib/rules"

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

        text .=replace /立 法院/, \立法院
        match text
        | /立法院第\s*(\S+)\s*屆第\s*(\S+)\s*會期第\s*(\S+?)\s*次臨時會(?:第\s*(\S+?)\s*次)?會議紀錄/ =>
            that.4 ?= 1
            @meta<[ad session extra sitting]> = that[1 to 4].map -> util.intOfZHNumber it
        | /立法院第\s*(\S+)\s*屆(?:第\s*(\S+)\s*會期)?(選舉院長、副院長|院長副院長選舉)會議(紀錄|議事錄)/ =>
            @meta<[ad session]> = that[1 to 2].map -> util.intOfZHNumber it
            @meta.sitting = 0
        | /立法院第\s*(\S+)\s*屆第\s*(\S+)\s*會期第\s*(\S+?)\s*次會議(紀錄|議事錄)/ =>
            @meta<[ad session sitting]> = that[1 to 3].map -> util.intOfZHNumber it
            @meta.memo = true if that.4 is \議事錄
        | /立法院第\s*(\S+)\s*屆第\s*(\S+)\s*會期第\s*(\S+?)\s*次秘密會議紀錄/ =>
            @meta<[ad session secret]> = that[1 to 3].map -> util.intOfZHNumber it
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
        if [_, item, content]? = text.match util.zhreghead
            item = util.parseZHNumber item
            text = content

            # XXX might not work if nested item number goes beyond number of
            # current level
            if item > @i + 1
                do
                    @output "#{++@i}. 未宣讀\n"
                while @i + 1 < item
            if @i + 1 == item
                @output "#{++@i}. #text\n"
                @last-item = @items[item] = {subject: content, conversation: []}
                return @
        @output "    #fulltext\n"
        @last-item.conversation.push [speaker, text]
        return @
    serialize: ->

class Exmotion
    ({@output = console.log, @indent_level = 0, @origCtx} = {}) ->
        @buffer = []
        @json = {}
        @state = ''
        @out-orig = @output
        @output = -> @buffer.push @indent it
        @output "## 臨時提案"
    newline: -> @buffer.push ''
    indent: -> it.replace /^/mg ' ' * @indent_level + '> '
    flush: ->
        [header, ...rest] = @buffer
        @out-orig header
        if @json.type  # if not empty
            @json.proposer &&= @name-fixup @json.proposer
            @json.petitioner &&= @name-fixup @json.petitioner
            @out-orig @indent ("```json\n" + JSON.stringify(@json, null, false) + "\n```").replace /^/mg, '    '
        for line in rest
            @out-orig line
        @json = {}
        @buffer = []
    push-rich: (html) ->
        @output html
        @newline!
    output-header: (fulltext, item) ->
        @output "### #fulltext"
        @json = { type: \exmotion, item }
        @newline!
    push-line: (speaker, text, fulltext) ->
        if fulltext is /^第(\S+)案/
            zhitem = that.1
            if zhitem isnt /\D/
                @output-header fulltext, zhitem
                return @
            if zhitem.match util.zhreg
                @flush!
                item = util.parseZHNumber zhitem
                @output-header fulltext, item
                return @

        current_state = ''
        split_names = -> it.split(/[　\s]+/)
        match fulltext
        | /^提案人：(.*)/ =>
            @json.proposer = split_names that.1
            current_state = \proposer
        | /^連署人：(.*)/ =>
            @json.petitioner = split_names that.1
            current_state = \petitioner
        | /^([^：]*)$/ =>
            line = that.0
            if @state == \petitioner
                @json[@state]= @json[@state] +++ split_names line
                current_state = @state
        | /.*有無異議？[（)](.*?)[）)].*/ =>
            switch that.1
            | \有 => @json.decision = 'tbd'
            | \無 => @json.decision = 'pass'
            | otherwise => console.error "unhandled case: #{that.1}"
        @state = current_state

        @output fulltext
        @newline!
        if (speaker ? @lastSpeaker) is \主席 and (text is /臨時提案.*處理完畢/ or text is /休息.*進行.*質詢/)
            @newline!
            @flush!
            return @origCtx
        @lastSpeaker = speaker if speaker
        return @
    name-fixup: (names) ->
        # Heuristic: merge two names if both are single words
        for i to names.length - 1
            if names[i]?.length == 1 and names[i+1]?.length == 1
                names[i] += names[i+1]
                names[i+1] = ''

        # Heuristic: split a long name into two with luck.  The data is wrong
        # back to doc->html phase. Here is a heuristic to make most cases work,
        # with exceptions like "李正宗靳曾珍麗" that require efforts to do
        # right (e.g. with a name dictionary).
        ret_names = []
        for name in names when name != ''
            if name.length == 6 and /‧/ != name
                ret_names.push name.substr(0, 3), name.substr(3, 3)
            else
                ret_names.push name
        ret_names
    serialize: -> @flush!

class Discussion
    ({@output} = {}) ->
        @output "\n## 討論事項\n\n"
        @lines = []
    push-line: (speaker, text, fulltext) ->
        @output "#fulltext\n"
        if (speaker ? @lastSpeaker) is \主席 and text is /討論事項.*到此為止(?!.*繼續)/
            return
        @lastSpeaker = speaker if speaker
        return @
    serialize: ->

class Consultation
    ({@output} = {}) ->
        @output "\n## 黨團協商結論\n\n"
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
        type = if @document => 'interpdoc' else 'interp'
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
        @subsection = true

    push-rich: (html) ->
        @current-conversation.push [ null, html ]
    push-line: (speaker, text, fulltext) ->
        if (speaker ? @lastSpeaker) is \主席 and text is /報告院會|詢答時間|已質詢完畢|處理完畢|提書面質詢/
            @flush!
            @output "* #fulltext\n"
            @conversation.push [speaker, text]
            @document = text is /提書面質詢/
        else if fulltext is /^(.*委員.*)書面(補充)?質詢?.?：$/
            @flush!
            @document = true
            @current-conversation.push [that.1, fulltext]
        else if !speaker? && @current-conversation.length is 0
            @conversation.push [speaker, text] # meeting actions
            @output "* #fulltext\n"
        else if @document
            @current-conversation.push [null, fulltext]
        else
            [_, h, m, text]? = text.match /^(?:\(|（)(\d+)時(\d+)分(?:\)|）)(.*)$/, ''
            entry = [speaker, text]
            #@output "* [#h, #m]\n" if h?
            @current-conversation.push [speaker, fulltext]
            if speaker => @current-participants.push speaker unless speaker in @current-participants
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
        if [_, item, content]? = text.match util.zhreghead
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
            after = null
            if imgs = node.find('img')
                if imgs.length
                    imgs.remove!
                    after = ~> @parseRich imgs
            tags = {}
            node.children!each -> tags[@.0.name] = true
            for name of tags => console.log \unhandled: name if name not in <[font br span u b a sup sub strong]>
            text = cleanup node
            return unless text.length
            return unless text is /\D/
            @parseLine text
            after?!
        else => console.error \unhandled: node.0.name, node.html!
    parseHtml: (data) ->
        self = @
        require! cheerio
        @$ = cheerio.load data, { +lowerCaseTags }
        @$('body').children!each -> self.parse @

class Parser implements HTMLParser
    ({@output = console.log, @output-json, @metaOnly} = {}) ->
        @lastSpeaker = null
        @ctx = @newContext Meta
    store: ->
        @ctx.serialize! if @ctx

    newContext: (ctxType, args = {}) ->
        @store!
        @ctx := if ctxType? => new ctxType args <<< {@output, @output-json} else null

    parseLine: (fulltext) ->
        text = fulltext
        [full, speaker, content]? = text.match /^([^：]{2,10})：(.*)$/
        if speaker
            if speaker is /以下|本案|本席|現作如下決(議|定)/ or speaker is /^(日期|傳真|電話|地址|剛才|再來|這樣|有句話說)/
                text = full
                speaker = null
            else if speaker is /^主席（(.*?)）/
                speaker = '主席'
                # XXX emit speaker meta
            else
                text = content

        if text is /報告院會/ and text is /現在散會/
            @store!
            @ctx := null

        if text is /^報\s*告\s*事\s*項$/
            @newContext Announcement
        else if text is /^質\s*詢\s*事\s*項(（本院委員質詢部分）)?$/
            @newContext Questioning
            @ctx .=push-line speaker, text, fulltext if that.2?
            @lastSpeaker = null
        else if text is /^討\s*論\s*事\s*項$/
            @newContext Discussion unless @ctx instanceof Discussion
        else if (speaker ? @lastSpeaker) is \主席 && text is /(現在進行討論事項|進行討論事項第\S+案)/ and @ctx !instanceof Discussion
            @newContext Discussion
            @ctx .=push-line speaker, text, fulltext
        else if (speaker ? @lastSpeaker) is \主席 && text is /處理.*黨團.*提案/
            @newContext Proposal
            @output "#fulltext\n\n"
        else if (speaker ? @lastSpeaker) is \主席 && text is /(處理.*黨團.*協商結論|現有一朝野黨團協商結論|宣讀朝野協商結論)/
            @newContext Consultation
            @output "#fulltext\n\n"
        else if (speaker ? @lastSpeaker) is \主席 && (text is /對行政院.*質詢/ or text is /進行施政報告之質詢|進行施政總質詢|追加預算報告之質詢|進行委員質詢|現在進行質詢。/) and text isnt /以下決定|現在休息|宣告|討論事項結束後|質詢完畢/ and @ctx !instanceof Interpellation
            @newContext Interpellation
            @ctx .=push-line speaker, text, fulltext
        else if (speaker ? @lastSpeaker) is \主席 && text is /處理.*復議案/
            @output "## 復議案\n\n"
            @newContext null
        else if (speaker ? @lastSpeaker) is \主席 and text is /現在.*(?!下次).*處理臨時提案/ and text isnt /不處理臨時提案/ and @ctx !instanceof Exmotion
            @newContext Exmotion, {origCtx: @ctx, indent_level: (if @ctx? => 4 else 0) + (@ctx?indent ? 0)}
            @ctx .=push-line speaker, text, fulltext
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
                @replaceWith('<hr />')
            else
                @attr \SRC "data:image/#ext;base64,"+(fs.readFileSync file)toString \base64

        @output rich.html! - /^\s+/mg - /\n/g - /position: absolute;/g

class MemoParser implements HTMLParser
    ({@output = console.log, @output-json, @metaOnly} = {}) ->
        @lastSpeaker = null
        @ctx = @newContext Meta
    store: ->
        @ctx.serialize! if @ctx

    newContext: (ctxType, args = {}) ->
        @store!
        @ctx := if ctxType? => new ctxType args <<< {@output, @output-json} else null

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


class BaseParser

    ({@output} = {}) ->
        @ctx = null
        @lastContext = null
        @rules= {}
        @meta = {}

    loadRules: (rulepath) ->
        @rules = new rules.Rules rulepath

    detectContext: (text) ->
        for trigger in @triggers
            if @rules.match trigger, text
                ctxname = @trigger2ctxname trigger
                return ctxname

    newContext: (ctxname) ->
        @lastContext = @ctx
        ctxType = eval ctxname
        @ctx := if ctxType? => new ctxType {@output} else null
        if @ctx
            @ctx.rules = @rules
            @ctx

    trigger2ctxname: (trigger) ->
        groupname = trigger.replace \.start ''
        groupname + "Context"

    parseText: (data) ->
        for line in data / "\n"
            if line.0 is \<
                @output line, "\n"
            else
                @parseLine line

    pushLine: (text, lastContext, triggers) ->
        @output "#text \n"
        @

# @FIXME: captialize class name
class headerContext extends BaseParser

class announcementContext extends BaseParser
    
class questioningContext extends BaseParser
    
class discussionContext extends BaseParser
     
class proposalContext extends BaseParser
    
class consulationContext extends BaseParser
    
class interpellationContext extends BaseParser
    
class breaktimeContext extends BaseParser

    pushLine: (text, last-context, triggers) ->
        @output "#text \n"

        # restore last context or start new context
        if @rules.match \breaktime.end text =>
            newctxname = @detectContext triggers
            lastctxname = last-context.constructor.name

            if newctxname != lastctxname
                last-context = @newContext newctxname
                lastctxname = newctxname

            @output "\n# #lastctxname \n\n"
            last-context
        else
            @
     
class endingContext extends BaseParser

class StructureFormater extends BaseParser

    ({@output = console.log, @output-json, @metaOnly} = {}) ->
        @ctx = null
        @rules = null
        @lastContext = null
        @result = {type:\processing_status}

        @triggers = <[announcement.start
                      questioning.start
                      discussion.start
                      proposal.start
                      consulation.start
                      interpellation.start
                      breaktime.start
                      ending.start]>

        # setup start ctx
        self = @
        @triggers.map ->
            ctxname = self.trigger2ctxname it
            self.result[ctxname] = false

        @newContext \headerContext
        @output "# headerContext \n\n"

    parseLine: (fulltext) ->
        throw "Excepted rules but it's empty." unless @rules
        text = fulltext

        @decideContext fulltext
        throw "parsed error! #fulltext is not belong to any context" unless @ctx

        @ctx .=pushLine fulltext, @lastContext, @triggers

    decideContext: (text) ->
        ctxname = @detectContext text

        if ctxname
            @result[ctxname] = true
            @output "# #ctxname \n\n"
            @newContext ctxname

    store: ->
        @output "# Processing status \n\n"
        @output "```json\n", JSON.stringify @result, null, 4b
        @output "\n```\n\n"

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
            content = text - /^\s*/ - /\s*$/

        match content
        | /[\s*（(](\d+時\d+分)[）)]\s*/ =>
            content = content.replace that.0, ''
            time = that.1
        {speaker, content, time}

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
        require! marked
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

module.exports = { Parser, TextParser, TextFormatter, MemoParser, StructureFormater, ResourceParser }
