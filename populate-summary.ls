require! \./lib/ly
require! <[optimist mkdirp fs async cheerio printf ./lib/util zhutil]>

{ad=8, session=3, extra=null, sittingRange="1:15"} = optimist.argv

err <- mkdirp "source/summary"
funcs = []

processItems = (body, cb) ->
    $ = cheerio.load body
    $('#queryListForm table tr').each ->
        [id] = @find "td a" .map -> @attr \onclick
            .map -> it.match /queryDetail1?\('(\d+)'\)/ .1
        # XXX: for discussion heading is _NOT_ part of content

        cols = @find \td .map -> @.text!
            .map -> it - /^\s*/mg
        return unless cols.length
        cb id, cols


parseAgenda = (g, body, doctype, type, cb) ->
    prevHead = null
    entries = []
    var last-announcement
    mapItem = (id, entry) -> switch type
        | \Announcement =>
            [heading, proposer, summary, result] = entry.0 / "\n"
            if heading is \null、
                item = ++last-announcement
            else
                [_, zhitem]? = heading.match util.zhreghead
                item = zhutil.parseZHNumber zhitem
                last-announcement := item
            {id, item, proposer, summary, result}
        | \Exmotion =>
            [heading, proposer, summary, result] = entry.0 / "\n"
            heading -= /^\(|\)$/g
            [_, zhitem]? = heading.match util.zhreg
            item = zhutil.parseZHNumber zhitem
            {id, item, proposer, summary, result}
        | \Discussion =>
            if doctype is \proceeding
                lines = entry.0 / "\n"
                return if lines.length <= 1
                if lines.length <= 2
                    result = lines.0
                else
                    [...line, result, _] = lines
                    line .= join ''
                    [_, zhitem, summary]? = line.match util.zhreghead
                    item = zhutil.parseZHNumber zhitem
                eod = no
                if result is /(〈|＜)其餘議案因未處理，不予列載。(＞|〉)$/
                    result -= /(〈|＜)其餘議案因未處理，不予列載。(＞|〉)$/
                    eod = yes
                [_, remark]? = summary?match /（([^（）]+)）$/
                dtype = match summary
                | void => 'other'
                | /^[^，]+臨時提案/ => 'exmotion'
                | /提請復議/        => 'reconsideration'
                | /(.*?)提議增列([^，]*)事項/ =>
                    console.log \changes that.1, that.2
                    'agenda'
                | otherwise => 'default'
                [_, origzhItem]? = summary?match /案原列討論事項第(.*?)案/
                origItem = zhutil.parseZHNumber origzhItem if origzhItem
                {id, item, dtype, summary, remark, result, origItem, eod}
            else if doctype is \agenda
                # kludge: source error - should be none
                return if g.ad is 8 and g.session is 1 and g.sitting is 1 and not g.extra
                [heading, content] = entry
                return unless content
                heading -= /\s*/g
                heading = prevHead unless heading.length
                [subzhItem, proposer, summary] = content / "\n"
                subzhItem -= /^\(|\)$/g
                subItem = zhutil.parseZHNumber subzhItem
                [_, zhitem]? = heading.match util.zhreghead
                item = zhutil.parseZHNumber zhitem
                prevHead := heading if heading
                {id, item, subItem, proposer, summary}


    processItems body, (id, entry) ->
        # XXX: extract resolution.  the other info can be found using
        # getDetails with id
        if doctype is \agenda and type is \Announcement and entry.length > 1
          _session = if g.extra
            printf "%02d-%02d", g.session, g.extra
          else
            printf "%02d", g.session

          _id = printf "%02d-%0s-%02d", g.ad, _session, g.sitting
          _sitting = entry.1?replace /\n/g ''
          unless _id is _sitting
            console.error "ignoring #{_sitting} #{_id}"
            return
        entries.push that if mapItem id, entry

    cb entries


populate = (g) ->
    doctype <- <[agenda proceeding]>.forEach
    types = <[Announcement Discussion]>
    types.push \Exmotion if doctype is \agenda
    type <- types.forEach
    funcs.push (done) ->
        getItems g, doctype, type, done

getItems = (g, doctype, type, cb) ->
    sitting = if g.extra
        "T#{g.sitting}-#{g.extra}"
    else
        g.sitting
    file = "source/summary/#{g.ad}-#{g.session}-#{sitting}-#{doctype}-#{type}.html"
    json = file.replace /\.html$/, '.json'

    extract = (body) ->
        parseAgenda g, body, doctype, type, (res) ->
            fs.writeFileSync json, JSON.stringify res, null 4
            cb res

    _, {size}? <- fs.stat json
    if size
        return cb require "./#json"

    _, {size}? <- fs.stat file
    if size
        extract fs.readFileSync file
    else
        body <- ly.getSummary g, doctype, type

        fs.writeFileSync file, body
        extract body

entryStatus = (res, def) -> match res
| /協商/    => \consultation
| /不予?通過/  => \rejected
| /通過/    => \passed
| /函請行政院研處/ => \ey
| /暫不予處理/ => \unhandled
| otherwise => def

prepare_motions = (g, cb) ->
    agenda <- getItems g, \agenda \Discussion
    exmotion <- getItems g, \agenda \Exmotion
    proceeding <- getItems g, \proceeding \Discussion
    eod = no
    items = if agenda.length => Math.max ...agenda.map (.item) else 0
    [eod] = [p.origItem ? p.item for p in proceeding when p.eod]
    inAgenda = [p for p in proceeding when p.origItem]
    if eod and !inAgenda.length # unaltered but unfinished
        inAgenda = []
        for {summary}:p in proceeding when p.item <= eod
            [key]? = summary.match /「(.*?)」/
            continue unless key
            [a] = [a for a in agenda when -1 isnt a.summary.indexOf key]
            continue unless a
            #console.log "for (#key) found: ",a.summary.indexOf key
            p.origItem = a.item
            inAgenda.push p
    for p in proceeding
        if p.dtype is \exmotion
            summary = p.summary - /^.*?，/ -  /((，|。)是否有當)?，請公決案。/ 
            summary .=replace /5噸以下/, '五噸以下'
            [ex] = [e for e in exmotion when summary is e.summary - /((，|。)是否有當)?，請公決案。/]
            unless ex
                [ex] = [e for e in exmotion when p.summary.indexOf(e.proposer - /，/) is 0]
            p.ref = ex
            console.error \unmatched p unless ex
        if p.dtype is \default
            unless p.origItem
                [a] = [a for a in agenda when p.summary.indexOf(a.summary) isnt -1]
                p.origItem = a.item if a

            if p.origItem
                p.ref = [a for a in agenda when a.item is p.origItem]
                inAgenda.push p unless p in inAgenda

#    for a in agenda when a.item not in proceeding.map (.origItem)
#        console.log a
    by_item = {[origItem, p] for {origItem}:p in proceeding when origItem}
    agendaResults = for a in agenda
        entry = {} <<< a
        entry.agendaItem = delete entry.item
        if proceeding.length
            if by_item[entry.agendaItem]
                entry <<< that{item, resolution: result, dtype}
            entry.status = entryStatus entry.resolution, \unhandled
        entry
    exmotionResults = exmotion.map (e) ->
        entry = {type: \exmotion, exItem: e.item} <<< e
        [res] = [ p for p in proceeding when p.ref is e ]
        entry <<< res{resolution: result, dtype, item} if res
        delete entry.result
        entry.status = entryStatus entry.resolution, \unhandled
        entry

    extraResults = for p in proceeding when !p.ref
        entry = {extra: true} <<< p
        entry.resolution = delete entry.result
        entry.status = entryStatus entry.resolution, \other
        entry

    all = agendaResults ++ exmotionResults ++ extraResults
    #console.log \==ERROR all.length, proceeding.length

    cb all

#ly.forGazette gazette, (id, g, type, entries, files) ->
#    return if ad and g.ad !~= ad
#    return if type isnt \院會紀錄
#    return if g.sitting != 9
#    populate g
#

prepare_announcement = (g, cb) ->
    agenda <- getItems g, \agenda \Announcement
    proceeding <- getItems g, \proceeding \Announcement
    results = for a in agenda
        entry = {} <<< a
        entry.agendaItem = delete entry.item
        entry
    by_id = {[id, a] for {id}:a in results}

    for {id,result} in proceeding
        unless entry = by_id[id]
          console.error "entry not found: #{id}"
          continue

        entry <<< {resolution: result}
        entry.status = match result ? ''
        | ''              => \accepted
        | /照案通過/      => \accepted
        | /提報院會/      => \accepted
        | /列席報告/      => \accepted
        | /多數通過/      => \accepted
        | /少數不通過/      => \rejected
        | /同意撤回/      => \retrected
        | /逕付(院會)?二讀/ => \prioritized
        | /黨團協商/      => \consultation
        | /交(.*)委員會/  => \committee
        | /中央政府總預算案/ => \committee
        | /展延審查期限/  => \extended
        | /退回程序委員會/ => \rejected
        | otherwise => console.error result; result
        # XXX: misq has altered agenda in agenda query result.  we need to
        # extract this info from gazette
        #if res.origItem isnt res.item
            #console.log "#{res.origItem} -> #{res.item}"
    cb results


parseProposer = (text) -> {text} <<< match text
| /本院(.*)黨團/ => caucus: [that.1] # XXX split
| /本院(.*)委員會/ => committee: [that.1] # XXX split
| otherwise => { government: text }
#| /本院委員(.*)等/ => { mly_primary: [that.1] } # XXX split


results = []
[start, end] = sittingRange.split \:

for sitting in [+start to +end] when sitting >0 => let sitting
    g = {ad, session, sitting, extra}
    funcs.push (done) ->
        ann <- prepare_announcement g
        motions <- prepare_motions g
        results.push {meeting: g, announcement: ann, discussion: motions}
        done!
err, res <- async.waterfall funcs
console.error \ok, res

console.log JSON.stringify results, null 4
/* mongo stuff later

{Bill, Announcement} = require \./lib/model

require! mongoose
mongoose.connect('mongodb://localhost/ly');

        motions = []
        funcs = ann.map (a) -> (next) ->
            err, bill, created <- Bill.findOrCreate do
                billNo: a.id
                proposer: parseProposer a.proposer
                summary: a.summary
            motions.push a{item, agenaItem, resolution} <<< bill: [bill]
            next!

        err, res <- async.waterfall funcs
        console.log \ok, motions.length
        A = new Announcement do
            sitting: g
            items: motions
        err <- A.save
        console.log \save err

        done!

mongoose.connection.close!
*/
