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
        return if speaker 
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

class Announcement
    ->
        @items = {}
        @last-item = null
    push-line: (speaker, text) ->
        if [_, item, content]? = text.match zhreg
            item = parseZHNumber item
            text = content
            @last-item = @items[item] = {subject: content, conversation: []}
        else
            @last-item.conversation.push [speaker, text]
        return @
    serialize: ->
        [\Announcement, @items]

class Proposal
    ->
        @lines = []
    push-rich: (node) ->
        console.error \NOTYET
        @lines.push [null, node.html!]
    push-line: (speaker, text) ->
        @lines.push [speaker, text]
        return @
    serialize: ->
        [\Proposal, @lines]

class Reconsideration extends Proposal
    serialize: ->
        [\Reconsideration, @lines]


class Questioning
    ->
        @ctx = ''
        @reply = {}
        @question = {}
        @current-conversation = []
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
                @conversation.push [ type, @current-conversation ]
            else
                @conversation = @conversation ++ @current-conversation
        @current-conversation = []
        @exmotion = false
        @subsection = true

    push-conversation: (speaker, text) ->
        if (speaker ? @lastSpeaker) is \主席 and text is /報告院會|詢答時間|已質詢完畢|處理完畢|提書面質詢/
            @flush!
            @conversation.push [speaker, text]
            @document = text is /提書面質詢/
        else if !speaker? && @current-conversation.length is 0
            @conversation.push [speaker, text] # meeting actions
        else
            [_, h, m, text]? = text.match /^(?:\(|（)(\d+)時(\d+)分(?:\)|）)(.*)$/, ''
            entry = [speaker, text]
            entry.push [+h, +m] if h?
            @current-conversation.push entry
        if speaker is \主席 and text is /現在.*處理臨時提案/
            @exmotion = true

        @lastSpeaker = speaker if speaker

    push-rich: (node) ->
        rich = $ '<div/>' .append node
        node.find('img').each -> @.attr \SRC, ''
        @push-conversation null, rich.html!
    push: (speaker, text) ->
        return @push-conversation speaker, text if @in-conversation
        if [_, item, content]? = text.match zhreg
            item = parseZHNumber item
            if @ctx is \question
                [_, speaker, content] = content.match /^(本院.*?)，(.*)$/
            text = content

        if item
            @[@ctx][item] = [speaker, text]
        else
            @in-conversation = true
            @push-conversation speaker, text

    push-line: (speaker, text) ->
        match text
        | /行政院答復部分$/ => @ctx = \reply
        | /本院委員質詢部分$/ => @ctx = \question
        | otherwise => @push speaker, text
        return @
    serialize: ->
        @flush!
        [\Interpellation, {answers: @reply, questions: @question, interpellation: @conversation}]

ctx = meta = new Meta
announcement = new Announcement
questioning = new Questioning
proposal = new Proposal
log = []

store = ->
    log.push ctx.serialize! if ctx

newContext = (ctxType) ->
    store!
    ctx := new ctxType

lastSpeaker = null

parse = ->
    switch @.0.name
    | \div   => @.children!each parse
    | \center   => @.children!each parse
    | \table => 
        ctx.push-rich @
    | \p     =>
        text = $(@)text! - /^\s+|\s$/g
        return unless text.length
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
            newContext Reconsideration
        else
            if ctx
                ctx .= push-line speaker, text
            else
                log.push [speaker, text]
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

console.log JSON.stringify { meta.meta, log }, null, 4
