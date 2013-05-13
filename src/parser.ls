require! {cheerio, crypto, marked, path, printf}
require! \js-yaml
require! "../lib/util"
require! "../lib/rules"

# create markdown head
md_header = (text, depth) ->
    depth ?= 1
    \# * depth + " #text"

# ad (appointed dates) (屆別)
# session (會期)
# sitting (會次)
class Meta
    ({@output, @rules, @output-json, @type = \院會紀錄} = {}) ->
        @output md_header @type + "\n\n" unless @type is \committee
        @meta = {}
    push-line: (speaker, text) ->
        if speaker
            @serialize!
            return
        if @ctx is \speaker
            [_, position, name] = @rules.match \common.name_with_title text
            return @

        text .=replace /立 法院/, \立法院
        #@FIXME: @rules.regexp in match syntax can not be compiled to right JavaScript, but we can use        #        (@)rules to workround it.
        header = false
        match text
        | (@)rules.regex \header.title_temporarily .exec =>
            that.4 ?= 1
            @meta<[ad session extra sitting]> = that[1 to 4].map -> util.intOfZHNumber it
        | (@)rules.regex \header.title_election .exec =>
            @meta<[ad session]> = that[1 to 2].map -> util.intOfZHNumber it
            @meta.sitting = 0
        | (@)rules.regex \header.title_committee .exec =>
            header = true
            @meta <<< do
                ad: that.1
                session: that.2
                sitting: that.4
                committee: util.parseCommittee that.3
        | (@)rules.regex \header.title_general .exec =>
            @meta<[ad session sitting]> = that[1 to 3].map -> util.intOfZHNumber it
            @meta.memo = true if that.4 is \議事錄
        | (@)rules.regex \header.title_secret .exec =>
            @meta<[ad session secret]> = that[1 to 3].map -> util.intOfZHNumber it
        | (@)rules.regex \header.title_other .exec =>
            @ctx = \speaker
            @meta.speaker = that.1
        | (@)rules.regex \header.datetime .exec =>
            @meta.datetime = util.datetimeOfLyDateTime that[1 to 3] [5 to 6]
        @output (if header => '# ' else ''), "#text\n"
        return @
    serialize: ->
        @output-json @meta if @output-json
        @output "```json\n", JSON.stringify @meta, null, 4b
        @output "\n```\n\n"

class Announcement
    ({@output = console.log} = {}) ->
        @output md_header \報告事項, 2
        @output "\n"
        @items = {}
        @last-item = null
        @i = 0
    indent-level: -> 4
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
        @output "    #fulltext"
        @output "" unless fulltext.0 is \|
        @last-item?.conversation.push [speaker, text]
        return @
    serialize: ->

class Exmotion
    ({@output = console.log, @origCtx, @rules} = {}) ->
        @buffer = []
        @json = {}
        @state = ''
        @indent_level = 0
        if @origCtx?.indent-level
            @indent_level = @origCtx?.indent-level!
        @out-orig = @output
        @output = -> @buffer.push @indent it
        @output md_header \臨時提案, 2
    newline: -> @buffer.push ''
    indent: -> it.replace /^/mg ' ' * @indent_level + '> '
    flush: ->
        [header, ...rest] = @buffer
        @out-orig header
        if @json.type  # if not empty
            @json.proposer &&= util.nameListFixup @json.proposer
            @json.petitioner &&= util.nameListFixup @json.petitioner
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
        | (@)rules.regex \exmotion.proposer .exec =>
            @json.proposer = split_names that.1
            current_state = \proposer
        | (@)rules.regex \exmotion.petitioner .exec  =>
            @json.petitioner = split_names that.1
            current_state = \petitioner
        | (@)rules.regex \exmotion.other .exec =>
            line = that.0
            if @state == \petitioner
                @json[@state]= @json[@state] ++ split_names line
                current_state = @state
        | (@)rules.regex \exmotion.disputed .exec =>
            switch that.1
            | \有 => @json.decision = 'tbd'
            | \無 => @json.decision = 'pass'
            | otherwise => console.error "unhandled case: #{that.1}"
        @state = current_state

        @output fulltext
        @newline! unless fulltext.0 is \|
        if (speaker ? @lastSpeaker) is \主席 and @rules.match \exmotion.end text
            @newline!
            @flush!
            return @origCtx
        @lastSpeaker = speaker if speaker
        return @
    serialize: -> @flush!

class Discussion
    ({@output, @rules} = {}) ->
        @output "\n" + md_header \討論事項, 2
        @output "\n"
        @_reset_state!
        @json = {}
    indent-level: -> 0
    push-line: (speaker, text, fulltext) ->
        if (speaker ? @lastSpeaker) is \主席 and @rules.match \discussion.end text
            @flush!
            return
        @lastSpeaker = speaker if speaker

        # breaktime
        if @rules.match \discussion.end text
            @flush!
            return @

        if @rules.match \discussion.item_start fulltext
            @flush!
            @current-state.item = that.1
            @output md_header that.1, 3
            return @

        match fulltext
        | (@)rules.regex \discussion.letter_start .exec =>
            @ctx = \letter
            @output md_header that.1, 4
            @outputjson {type:\discussion_letter_start, comment: \函開始}
            @output!
            return @
        | (@)rules.regex \discussion.resolution .exec =>
            @current-state.resolution.text = that.2
            @ctx = \決議
        # 附帶決議
        | (@)rules.regex \discussion.other_resolution_start .exec =>
            @ctx = \附帶決議
        | (@)rules.regex \discussion.letter_end .exec =>
            meta = {type:\discussion_letter_end, comment:\函結束或審查報告內文結束}
            @outputjson meta
            @ctx = null
        | (@)rules.regex \discussion.discusswords_start .exec =>
            @outputjson {type:\discussion_discusswords_start, stage: that.2, comment: \逐條討論開始}

            @ctx = \逐條討論
        | (@)rules.regex \discussion.discusswords_end .exec =>
            @outputjson {type:\discussion_discusswords_end, comment: \逐項討論結束}

            @ctx = \決議

        need_output_orig = true
        # 通過?
        if @ctx is \決議 or @ctx is \附帶決議
            need_output_orig = @handle_resolution fulltext
        # 處理附件
        else if @ctx is \letter
            need_output_orig = @handle_letter fulltext
        # @TODO:處理逐條討論
        if need_output_orig
            @output fulltext
            @output "" unless fulltext.0 is \|

        return @

    handle_letter: (fulltext) ->
        match fulltext
        # output meta
        | /附件/ =>
            @json.type = \discussion_letter_meta
            @outputjson @json
        | (@)rules.regex \discussion.report_start .exec =>
            throw "previous ctx is not letter" unless @ctx is \letter
            @ctx = \report
            @output "#fulltext\n"
            @outputjson {type: \discussion_report_start, comment: \審查報告內文開始}
            return false
        | (@)rules.regex \discussion.letter_to .exec =>
            @json.to = that.1
        | (@)rules.regex \discussion.letter_date .exec =>
            @json.publish_date = util.datetimeOfLyDateTime that[1 to 3]
        | (@)rules.regex \discussion.letter_id .exec =>
            @json.id = that.1
        | (@)rules.regex \discussion.letter_title .exec =>
            @json.title = that.1
        | (@)rules.regex \discussion.letter_priority .exec =>
            @json.priority = that.1
        | (@)rules.regex \discussion.letter_secure .exec =>
            @json.secure = that.1
        | (@)rules.regex \discussion.letter_report_to_start .exec  =>        
            @json.report_to = []
            # XXX: The parser does not handle report id in old gazettes
            unless that.1
                console.log "warn: can not parse report id in discussion ctx because it is old format"
                return 
            res = @rules.match \discussion.letter_report_to_id, that.1, \g
            unless res
                console.log "warn: can not parse report id in discussion ctx because it is old format"
                return

            for e in res
                matched = @rules.match \discussion.letter_report_to_id e
                throw "report_to field of letter pasred failed" unless matched
                @json.report_to.push {id: matched.4, publish_date: util.datetimeOfLyDateTime matched[1 to 3]}

    handle_resolution: (fulltext) ->
        match fulltext 
        | (@)rules.regex \exmotion.disputed .exec =>
            _type = if @ctx is \決議
                    then \resolution
                    else \other_resolution
            switch that.1
            | \有 => @current-state[_type].decision = 'tbd'
            | \無 => @current-state[_type].decision = 'pass'
            | otherwise => console.error "unhandled case: #{that.1}"
            @ctx = \決議

        switch @ctx
        | \決議 =>
            if @current-state.resolution.text is /協商/
                @current-state.resolution.decision = \tbd
            else
                @current-state.resolution.decision ?= \pass
        | \附帶決議 =>
            @current-state.other_resolution.text = fulltext
    flush: ->
            if @current-state.item
                @outputjson @current-state
                @_reset_state!
    _reset_state: ->
            @ctx = \決議
            @current-state = {type: \discussion, resolution:{}, other_resolution:{}}
    serialize: -> @flush!
    outputjson: (json)->
            @output [
                * \```json
                * JSON.stringify json, null, 4b
                * \```
            ].join "\n"
            @json = {}

class Consultation
    ({@output} = {}) ->
        @output "\n" + md_header \黨團協商結論, 2
        @output "\n"
        @lines = []
    indent-level: -> 0
    push-line: (speaker, text, fulltext) ->
        @output "#fulltext\n"
        return @
    serialize: ->

class Proposal
    ({@output} = {}) ->
        @output md_header \黨團提案, 2
        @output "\n"
        @lines = []
    indent-level: -> 0
    push-line: (speaker, text, fulltext) ->
        @output fulltext
        @output '' unless fulltext.0 is \|
        return @
    serialize: ->


class Interpellation
    ({@output, @lastSpeaker, @rules} = {}) ->
        @current-conversation = []
        @current-participants = []
        @conversation = []
        @subsection = false
        @document = false
    indent-level: -> 4
    flush: ->
        type = if @document => 'interpdoc' else 'interp'
        if @current-conversation.length
            if @subsection
                people = if type is 'interp' => @current-participants else null
                shasum = crypto.createHash('sha1')
                shasum.update("#{ JSON.stringify @current-conversation }")
                digest = shasum.digest('hex')
                meta = {type, people, digest}
                @output "    ```json\n    #{ JSON.stringify meta }\n    ```"
                itemprefix
                for [speaker, fulltext] in @current-conversation
                    itemprefix = if type is 'interp'
                        if speaker => '* ' else '    '
                    else
                        ''
                    @output "    #itemprefix#fulltext"
                    @output '' unless fulltext.0 is \|
                @conversation.push [ type, @current-conversation ]
            else
                for [speaker, fulltext] in @current-conversation => @output "* #fulltext\n"
                @conversation = @conversation ++ @current-conversation
        @current-conversation = []
        @current-participants = []
        @subsection = true

    push-rich: (html) ->
        @current-conversation.push [ null, html ]
    push-line: (speaker, text, fulltext) ->
        if (speaker ? @lastSpeaker) is \主席 and @rules.match \interpellation.end text
            @flush!
            @output "* #fulltext\n"
            @conversation.push [speaker, text]
            @document = @rules.match \interpellation.interpdoc_start text
        else if @rules.match \interpellation.interpdoc_body fulltext
            @flush!
            @document = true
            @current-conversation.push [that.1, fulltext]
        else if !speaker? && @current-conversation.length is 0
            @conversation.push [speaker, text] # meeting actions
            @output "* #fulltext\n"
        else if @document
            @current-conversation.push [null, fulltext]
        else
            [_, h, m, text]? = text.match @rules.regex \speach.content, ''
            entry = [speaker, text]
            #@output "* [#h, #m]\n" if h?
            @current-conversation.push [speaker, fulltext]
            if speaker => @current-participants.push speaker unless speaker in @current-participants
        @lastSpeaker = speaker if speaker
        @
    serialize: -> @flush!

class Questioning
    ({@output, @rules} = {}) ->
        @output md_header \質詢事項, 2
        @output "\n"
        @ctx = null
        @reply = {}
        @question = {}
    indent-level: -> 0
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
        | (@)rules.regex \questioning.reply_start .exec  =>
            @output "\n" + md_header \行政院答復部分, 3
            @output!
            @ctx = \reply
        | (@)rules.regex \questioning.question_start .exec  =>
            @output "\n" + md_header \本院委員質詢部分, 3
            @output!
            @ctx = \question
        | otherwise => @push speaker, text, fulltext
        return @
    serialize: ->

class DummyContext
    ({@output = console.log}) ->
    indent-level: -> 0
    push-line: (speaker, text, fulltext) ->
        @output "#fulltext\n\n"
        @
    serialize: ->

# It works more like a filter, that collect data pass to origCtx for output.
# With that, we don't need to worry about the output style of origCtx.
class Vote
    ({@output = console.log, @origCtx, @rules} = {}) ->
        @vote = {}
        @current_vote = null
    push-line: (speaker, text, fulltext) ->
       
        match fulltext
        | (@)rules.regex \vote.vote_approval .exec =>
            @current_vote = \approval
        | (@)rules.regex \vote.vote_veto .exec =>
            @current_vote = \veto
        | (@)rules.regex \vote.vote_abstention .exec =>
            @current_vote = \abstention
        | (@)rules.regex \vote.vote_other .exec  =>
            if @current_vote
                indent = ''
                if @origCtx.indent-level
                    indent = ' ' * @origCtx.indent-level!
                @output "#indent```json\n#indent#{ JSON.stringify @vote }\n#indent```\n"
            @origCtx.push-line speaker, text, fulltext
            return @origCtx
        | _ =>
            if @current_vote
                @vote[@current_vote] ||= []
                @vote[@current_vote] = @vote[@current_vote] ++ util.nameListFixup fulltext.split(/[　\s]+/)
        @origCtx.push-line speaker, text, fulltext
        return @
    serialize: -> @origCtx.serialize!

HTMLParser = do
    parse: (node) ->
        self = @
        cleanup = (node) ~>
            text = @$(node)text! - /^\s+|\s+$/g
            text.=replace /\s*\n+\s*/g, ' '
            text

        match node.0.name
        | \div =>
            return if node.attr(\TYPE) is /header|footer/i
            node.children!each -> self.parse @
        | /multicol|div|center|dd|dl|ol|ul|li/ => node.children!each -> self.parse @
        | \h1 =>
            @parseLine cleanup node
        | \h2 =>
            @parseLine cleanup node
        | \table => @parseRich node
        | \p     =>
            after = null
            node.find \strike .remove!
            node.find \sdfield .remove!
            if tables = node.find('table')
                if tables.length
                    tables.remove!
                    a = after
                    after = ~> a?!; @parseRich tables
            if imgs = node.find('img')
                if imgs.length
                    imgs.remove!
                    after = ~> @parseRich imgs
            tags = {}
            node.children!each -> tags[@.0.name] = true
            for name of tags => console.log "\nunhandled:" name if name not in <[font br span u b a sup sub strong center ]>
            cleanup node
                if ..length and .. is /\D/
                    @parseLine ..
            after?!
        else => console.error \unhandled: node.0.name, node.html!
    parseHtml: (data) ->
        self = @
        require! cheerio
        @$ = cheerio.load data, { +lowerCaseTags }
        @$('body').children!each -> self.parse @

class LogParser
    store: ->
        @ctx.serialize! if @ctx

    newContext: (ctxType, args = {}) ->
        @store!
        @ctx := if ctxType? => new ctxType args <<< {@output, @output-json} else null

    prepareLine: (text) ->
        [full, speaker, content]? = @rules.match \speach.paragraph text
        if speaker
            if @rules.match \speach.ignore_speakers speaker
                text = full
                speaker = null
            else if @rules.match \speach.chairman speaker
                speaker = '主席'
                # XXX emit speaker meta
            else
                text = content
        [speaker, text]

    push-line: (speaker, text, fulltext) ->
        if @ctx
            @ctx .=push-line speaker, text, fulltext
        else
            @output "#fulltext"
            @output "\n" unless fulltext.0 is \|

class YSLogParser extends LogParser
    ({@output = console.log, @rules, @output-json, @metaOnly} = {}) ->
        @lastSpeaker = null
        @ctx = @newContext Meta, {rules: @rules}
    parseLine: (fulltext) ->
        [speaker, text] = @prepareLine fulltext

        if text is /報告院會/ and text is /現在散會/
            @store!
            @ctx := null

        if @rules.match \announcement.title text
            @newContext Announcement
        else if @rules.match \questioning.start text
            @newContext Questioning, {rules: @rules}
            @ctx .=push-line speaker, text, fulltext if that.2?
            @lastSpeaker = null
        else if @rules.match \discussion.title text
            @newContext Discussion, {rules: @rules} unless @ctx instanceof Discussion
        else if (speaker ? @lastSpeaker) is \主席 && @rules.match \discussion.start text and @ctx !instanceof Discussion
            @newContext Discussion, {rules: @rules}
            @ctx .=push-line speaker, text, fulltext
        else if (speaker ? @lastSpeaker) is \主席 && @rules.match \proposal.start text
            @newContext Proposal
            @output "#fulltext\n\n"
        else if (speaker ? @lastSpeaker) is \主席 && @rules.match \consultation.start text
            @newContext Consultation
            @output "#fulltext\n\n"
        else if (speaker ? @lastSpeaker) is \主席 && (((@rules.match \interpellation.start text) and not @rules.match \interpellation.ignore_start text) or @rules.match \interpellation.ask_someone_report text) and @ctx !instanceof Interpellation
            @newContext Interpellation, {lastSpeaker: @lastSpeaker, rules: @rules}
            @ctx .=push-line speaker, text, fulltext
        else if (speaker ? @lastSpeaker) is \主席 && @rules.match \reconsideration.start text
            @output md_header \復議案, 2
            @output "\n"
            @newContext null
        else if (speaker ? @lastSpeaker) is \主席 and @rules.match \exmotion.start text and not @rules.match \exmotion.ignore_start text and @ctx !instanceof Exmotion
            @newContext Exmotion, {origCtx: @ctx, rules: @rules}
            @ctx .=push-line speaker, text, fulltext
        else if fulltext is /.*表決結果名單.*/
            if !@ctx
               @newContext DummyContext
            @ctx .=push-line speaker, text, fulltext
            @newContext Vote, {origCtx: @ctx, rules: @rules}
        else
            @push-line speaker, text, fulltext
        @lastSpeaker = speaker if speaker

    parseRich: (node) ->
        rich = @$ '<div/>' .append node
        rich.find('img').each -> @.attr \SRC, ''
        if @ctx?push-rich
            @ctx.push-rich rich.html!
        else
            @output "    ", rich.html!, "\n"
TextParser = do
    parseText: (data) ->
        for line in data / "\n"
            line = '* * *' if line is '<hr>'
            if line.0 is \<
                if @ctx?push-rich
                    @ctx.push-rich line
                else
                    @output line, "\n"
            else
                @parseLine line

LogContext = do
    output-meta: (meta, indent, prefix) ->
        @output-json meta if @output-json
        json = ["```json", JSON.stringify(meta, null, 4b), "```\n\n"].join "\n"
        @output json.replace /^/mg, ' ' * indent + prefix

class CommitteeAnnouncement implements LogContext
    ({@output = console.log, @rules} = {}) ->
        @output md_header \報告事項, 2
        @output "\n"
        @items = {}
        @last-item = null
        @i = 0
    indent-level: -> 4
    push-rich: (html) ->
        @push-line null, html, html
    push-line: (speaker, text, fulltext) ->
        if fulltext is '* * *'
            if @proceeding
                @output-meta @meta, 4, '> '

                for line in @proceeding
                    @output '' unless line.0 is \|
                    @output "    > #line"
                @proceeding = false
            else
                @proceeding = []
            @output "    > #fulltext\n"
            return @

        if @proceeding
            if @rules.regex \header.title_committee .exec fulltext
                @meta = { type: \proceeding } <<< do
                    ad: that.1
                    session: that.2
                    sitting: that.4
                    committee: util.parseCommittee that.3
                fulltext = "## " + fulltext
            @proceeding.push fulltext
            return @

        if [_, item, content]? = text?match util.zhreghead
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
        @output (if @last-item => "    " else ''), fulltext
        @output '' unless fulltext.0 is \|
        @last-item?.conversation.push [speaker, text]
        return @
    serialize: ->

class CommitteeLogParser extends LogParser
    ({@output = console.log, @rules, @output-json, @metaOnly} = {}) ->
        @lastSpeaker = null
        @ctx = @newContext Meta, {@rules, type: \committee}
    parseLine: (fulltext) ->
        [speaker, text] = @prepareLine fulltext
        if !@ctx and @rules.match \announcement.title text
            @newContext CommitteeAnnouncement, {@rules}
            return
        @push-line speaker, text, fulltext
    parseRich: (node) ->


class TextFormatter implements HTMLParser
    ({@output = console.log, @context-cb, @rules, @chute = true} = {}) ->
        if @chute
            @chute-map = try require \../data/chute-map
            @chute-map ?= {}

    parseLine: ->
        if it.0 is \<
            it-= /^<|>/g
        if @context-cb
            if it is /紀錄$/ and @rules.regex \header.title_committee .exec it
                @context-cb do
                    ad: that.1
                    session: that.2
                    sitting: that.4
                    committee: util.parseCommittee that.3
        @output it

    parseRich: (node) ->
        require! <[execSync fs]>
        rich = @$ '<div/>' .append node
        self = @
        convert = []
        rich.find('img').each ->
            src = @attr \SRC
            file = self.base + '/' + src
            [_, ext] = src.match /\.(\w+)$/
            output = exec-sync.stdout "imgsize #file"
            [_, width, height] = output.match /width="(\d+)" height="(\d+)"/
            if width / height > 60
                @replaceWith('<hr />')
            else if self.chute
                if [id, shortcut]? = self.chute-map[file]
                    uri = "//media.getchute.com/media/#shortcut"
                uri ?= exec-sync.stdout "lsc ./img-filter.ls #file"
                @attr \SRC uri

        if node.0.name is \table and !node.find \table .length
            cleanup = ->
                it -= /^\s+|\s+$/g
                it.=replace /\s*\n\s*/g '<br>'
                it
            rows = node.find 'tr,th' .map -> @
            rcontent = rows.map(-> it.find \td .map -> cleanup @text!)
            ncol = Math.max null ...rcontent.map (.length)
            # screen width hack
            swidth = -> it.length * 2 - (it.match(/[\u0000-\u007f]/g)?length ? 0)
            colsize = for i in [0 til ncol]
                # gfm table cols need to be at least 3 bytes
                Math.max.apply null [3] ++ rcontent.map ->
                    if it[i]
                        swidth it[i]
                    else
                        0
            [rhead, ...rbody] = rcontent
            @output ''
            for row, r in [rhead, colsize.map -> '-' * it] ++ rbody
                col = for c in [0 til ncol]
                    col = row[c]
                    col = '\u3000' * (colsize[c] / 2) if !col
                    ' ' * (colsize[c] - swidth col) + col
                @output '| ' + col.join ' | '

            return

        @output rich.html! - /^\s+/mg - /\n/g - /position: absolute;/g

class BillParser extends TextFormatter
    parseRich: (node) ->
        if node.0.name is \table
            [first, ...rest] = node.find \tr .map -> @
            match first.text! - /\s/g
            | /^院總第(\d+)號(.*)提案第(\d+)號$/ =>
                @output "提案編號：#{that.1}#{that.2.0}#{that.3}"
                return
            | /^(?:「?(.*草案?)」?)?(?:條文)?(對照表)?$/ =>
                name = that.1
                type = if that.2 => \lawdiff else \lawproposal
                [h, ...content] = rest
                header = h.find \td .map -> @text! - /^\s*|\s*$/gm
                tosplit = [i for h, i in header when h is \說明 or h.match /\n/ or h.match /NOTYET委員等提案/]
                content .= map ->
                    it.find \td .map -> @text! - /^\s*|\s*$/gm
                # a column can contain multiple proposals.  splice them into individual diff
                derived-names = []
                for i in tosplit.reverse!
                    names = derived-names ++ header[i].split /\n/
                    header[i to i] = names
                    for e,j in content
                        x = e[i]split /(委員.*提案|審查會)：\n/
                        first = x.shift!
                        [which] = [h for h in header when h is /增訂條文|修正條文/]
                        splitted = {}
                        splitted[which] = first if which?
                        while who = x.shift!
                            if header[i] isnt \說明
                                throw "#who not in #names" unless who in names
                            #else
                            #    derived-names.push who unless who in names
                            splitted[who] = x.shift! - /\s*$/
                        replaced-with = if header[i] is \說明
                            [splitted]
                        else
                            [splitted[who] ? '' for who in names]
                        e.splice i, 1, ...replaced-with
                [i] = [j for h, j in header when h is \審查會通過條文]
                [comment] = [j for h, j in header when h is \說明]
                if i?
                    for e in content
                        e[i] -= /^(（.*?）\n)/
                        e[comment].審查會? .= replace /^/, RegExp.$1


                @output-json { type, name, header, content }
                return

        super ...

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
        @triggers = []

    loadRules: (rulepath) ->
        @rules = new rules.Rules rulepath

    detectContext: (text, triggers) ->
        _triggers = if triggers
                    then triggers
                    else @triggers
        for trigger in _triggers
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
            lastctxname = last-context.constructor.name
            newctxname = @detectContext text, triggers
            if not newctxname or newctxname == lastctxname
                @output "\n# #lastctxname \n\n"
                last-context
            else
                @output "\n# #newctxname \n\n"
                @newContext newctxname
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
        @output "```json\n" + JSON.stringify @result, null, 4b
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

module.exports = { YSLogParser, TextParser, HTMLParser, TextFormatter, MemoParser, StructureFormater, ResourceParser, BillParser, CommitteeLogParser }
