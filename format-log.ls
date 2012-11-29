require! {cheerio, optimist, fs, request}

{id, _} = optimist.argv

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
    ->
        @meta = {raw: []}
    push-line: (speaker, text) ->
        if speaker 
            @serialize!
            return 
        if @ctx is \speaker
            [_, position, name] = text.match /^(?:(.+)\s+)?(.*)$/
            @meta.raw.push text
            return @

        match text
        | /立法院第(\d+)屆第(\d+)會期第(\d+)次會議紀錄/ =>
            @meta<[ad session sitting]> = that[1 to 3]
        | /主\s*席\s+(.*)$/ =>
            @ctx = \speaker
            @meta.speaker = that.1
        @meta.raw.push text
        return @
    serialize: ->
        console.log "# 院會紀錄\n\n"
        console.log "```json\n", JSON.stringify @meta, null, 4b
        console.log "\n```\n\n"

class Announcement
    ->
        console.log "## 報告事項\n\n"
        @items = {}
        @last-item = null
        @i = 0
    push-line: (speaker, text, fulltext) ->
        if [_, item, content]? = text.match zhreg
            item = parseZHNumber item
            text = content
            @i++
            console.log "#{@i}. #text\n"
            @last-item = @items[item] = {subject: content, conversation: []}
        else
            console.log "    #fulltext\n"
            @last-item.conversation.push [speaker, text]
        return @
    serialize: ->

class Proposal
    ->
        console.log "## 黨團提案\n\n"
        @lines = []
    push-line: (speaker, text, fulltext) ->
        console.log "fulltext\n"
        return @
    serialize: ->


class Questioning
    ->
        console.log "## 質詢事項\n\n"
        @ctx = ''
        @reply = {}
        @question = {}
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
                console.log "    ```json\n    #{ JSON.stringify meta }\n    ```"
                itemprefix 
                for [speaker, fulltext] in @current-conversation
                    itemprefix = if type is 'interp'
                        if speaker => '* ' else '    '
                    else
                        ''
                    console.log "    #itemprefix#fulltext\n"
                @conversation.push [ type, @current-conversation ]
            else
                for [speaker, fulltext] in @current-conversation => console.log "* #fulltext\n"
                @conversation = @conversation +++ @current-conversation
        @current-conversation = []
        @current-participants = []
        @exmotion = false
        @subsection = true

    push-rich: (node) ->
        @current-conversation.push [ null, node.html! ]
    push-conversation: (speaker, text, fulltext) ->
        if (speaker ? @lastSpeaker) is \主席 and text is /報告院會|詢答時間|已質詢完畢|處理完畢|提書面質詢/
            @flush!
            console.log "* #fulltext\n"
            @conversation.push [speaker, text]
            @document = text is /提書面質詢/
        else if !speaker? && @current-conversation.length is 0
            @conversation.push [speaker, text] # meeting actions
            console.log "* #fulltext\n"
        else
            [_, h, m, text]? = text.match /^(?:\(|（)(\d+)時(\d+)分(?:\)|）)(.*)$/, ''
            entry = [speaker, text]
            #console.log "* [#h, #m]\n" if h?
            @current-conversation.push [speaker, fulltext]
            if speaker => @current-participants.push speaker unless speaker in @current-participants
        if speaker is \主席 and text is /現在.*處理臨時提案/
            @exmotion = true

        @lastSpeaker = speaker if speaker

    push: (speaker, text, fulltext) ->
        return @push-conversation speaker, text, fulltext if @in-conversation
        if [_, item, content]? = text.match zhreg
            item = parseZHNumber item

        if item
            @[@ctx][item] = [speaker, text]
            console.log "#item. #content"
        else
            @in-conversation = true
            console.log "\n"
            @push-conversation speaker, text, fulltext

    push-line: (speaker, text, fulltext) ->
        match text
        | /行政院答復部分$/ =>
            console.log "\n" + '### 行政院答復部分' + "\n"
            @ctx = \reply
        | /本院委員質詢部分$/ =>
            console.log "\n" + '### 本院委員質詢部分' + "\n"
            @ctx = \question
        | otherwise => @push speaker, text, fulltext
        return @
    serialize: ->
        @flush!

ctx = meta = new Meta
log = []

store = ->
    log.push ctx.serialize! if ctx

newContext = (ctxType) ->
    store!
    ctx := if ctxType? => new ctxType else null

lastSpeaker = null

parse = ->
    switch @.0.name
    | \div   => @.children!each parse
    | \center   => @.children!each parse
    | \table => 
        rich = $ '<div/>' .append @
        rich.find('img').each -> @.attr \SRC, ''
        if ctx?push-rich
            ctx.push-rich rich
        else
            console.log "    ", rich.html!, "\n"
    | \p     =>
        text = $(@)text! - /^\s+|\s$|\n/g
        return unless text.length
        fulltext = text
        [full, speaker, content]? = text.match /^([^：]{2,10})：(.*)$/
        if speaker
            if speaker is /以下/
                text = full
                speaker = null
            else
                text = content

        if text is /報告院會/ and text is /現在散會/
            store!
            ctx := null

        if text is /^報\s+告\s+事\s+項$/
            newContext Announcement
        else if text is /^質\s+詢\s+事\s+項$/
            newContext Questioning
        else if (speaker ? lastSpeaker) is \主席 && text is /處理.*黨團.*提案/
            newContext Proposal
        else if (speaker ? lastSpeaker) is \主席 && text is /處理.*復議案/
            console.log "## 復議案\n\n"
            newContext null
        else
            if ctx
                ctx .:= push-line speaker, text, fulltext
            else
                console.log "#fulltext\n\n"
        lastSpeaker := speaker if speaker
    else => console.error \unhandled: @.0.name , @.html!

fixup = ->
    it.replace /\uE58E/g, '冲'

for file in _
    data = fs.readFileSync file, \utf8
    data = fixup data
    $ = cheerio.load data, { +lowerCaseTags }
    $('body').children!each parse
store!
