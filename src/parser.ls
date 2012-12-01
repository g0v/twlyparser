require! {cheerio}

zhnumber = <[○ 一 二 三 四 五 六 七 八 九 十]>

zhmap = {[c, i] for c, i in zhnumber}
zhreg = new RegExp "^((?:#{ zhnumber * '|' })+)、(.*)$", \m

parseZHNumber = ->
    if it.0 is \十
        l = it.length
        return 10 if l is 1
        return 10 + parseZHNumber it.slice 1
    if it[*-1] is \十
        return 10 * parseZHNumber it.slice 0, it.length-1
    res = 0
    for c in it when c isnt \十
        res *= 10
        res += zhmap[c]
    res

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
        | /立法院第(\S+)屆第(\S+)會期第(\S+)次會議紀錄/ =>
            @meta<[ad session sitting]> = that[1 to 3].map ->
                | it.0 in zhnumber => parseZHNumber it
                else => +it
        | /主\s*席\s+(.*)$/ =>
            @ctx = \speaker
            @meta.speaker = that.1
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
        if [_, item, content]? = text.match zhreg
            item = parseZHNumber item
            text = content
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

    push-rich: (node) ->
        @current-conversation.push [ null, node.html! ]
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
        if [_, item, content]? = text.match zhreg
            item = parseZHNumber item

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

class Parser
    ({@output = console.log, @output-json, @metaOnly} = {}) ->
        @lastSpeaker = null
        @ctx = @newContext Meta
    parseHtml: (data) ->
        self = @
        @$ = cheerio.load data, { +lowerCaseTags }
        @$('body').children!each -> self.parse @

    store: ->
        @ctx.serialize! if @ctx

    newContext: (ctxType) ->
        @store!
        @ctx := if ctxType? => new ctxType {@output, @output-json} else null

    parse: (node) ->
        self = @
        pass-through = -> it.children!each -> self.parse @
        switch node.0.name
        | \multicol   => pass-through node
        | \div        => pass-through node
        | \center     => pass-through node
        | \dd         => pass-through node
        | \dl         => pass-through node
        | \ol         => pass-through node
        | \li         => pass-through node
        | \table => 
            rich = @$ '<div/>' .append node
            rich.find('img').each -> @.attr \SRC, ''
            if @ctx?push-rich
                @ctx.push-rich rich
            else
                @output "    ", rich.html!, "\n"
        | \p     =>
            text = @$(node)text! - /^\s+|\s+$/g
            text.=replace /\s*\n+\s*/g, ' '
            return unless text.length
            return unless text is /\D/
            fulltext = text
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
        else => console.error \unhandled: node.0.name, node.html!


module.exports = { Parser }
