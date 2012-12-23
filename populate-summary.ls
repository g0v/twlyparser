require! \./lib/ly
require! <[optimist mkdirp fs async cheerio ./lib/util]>
{Bill, Announcement} = require \./lib/model

{gazette, ad, lodev, type, force} = optimist.argv

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
    mapItem = (id, entry) -> switch type
        | \Announcement =>
            [heading, proposer, summary, result] = entry.0 / "\n"
            [_, zhitem]? = heading.match util.zhreghead
            item = util.parseZHNumber zhitem
            {id, item, proposer, summary, result}
        | \Exmotion =>
            [heading, proposer, summary, result] = entry.0 / "\n"
            heading -= /^\(|\)$/g
            [_, zhitem]? = heading.match util.zhreg
            item = util.parseZHNumber zhitem
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
                    item = util.parseZHNumber zhitem
                eod = no
                if result is /(〈|＜)其餘議案因未處理，不予列載。(＞|〉)$/
                    result -= /(〈|＜)其餘議案因未處理，不予列載。(＞|〉)$/
                    eod = yes
                [_, remark]? = summary?match /（([^（）]+)）$/
                dtype = match summary
                | undefined => 'other'
                | /^[^，]+臨時提案/ => 'exmotion'
                | /提請復議/        => 'reconsideration'
                | /(.*?)提議增列([^，]*)事項/ =>
                    console.log \changes that.1, that.2
                    'agenda'
                | otherwise => 'default'
                [_, origzhItem]? = summary?match /案原列討論事項第(.*?)案/
                origItem = util.parseZHNumber origzhItem if origzhItem
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
                subItem = util.parseZHNumber subzhItem
                [_, zhitem]? = heading.match util.zhreghead
                item = util.parseZHNumber zhitem
                prevHead := heading if heading
                {id, item, subItem, proposer, summary}


    processItems body, (id, entry) ->
        # XXX: extract resolution.  the other info can be found using
        # getDetails with id
        res = mapItem id, entry
        entries.push res if res

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

    extract = (body) ->
        parseAgenda g, body, doctype, type, cb

    _, {size}? <- fs.stat file
    if size
        extract fs.readFileSync file
    else
        body <- ly.getSummary g, doctype, type

        fs.writeFileSync file, body
        extract body

prepare_motions = (g, cb) ->
    agenda <- getItems g, \agenda \Discussion
    exmotion <- getItems g, \agenda \Exmotion
    proceeding <- getItems g, \proceeding \Discussion
    eod = no
    items = if agenda.length => Math.max ...agenda.map (.item) else 0
    [eod] = [p.origItem ? p.item for p in proceeding when p.eod]
    inAgenda = [p for p in proceeding when p.origItem]
    if eod and !inAgenda.length # unaltered but unfinished
        inAgenda = for p in proceeding when p.item <= eod
            p.origItem = p.item
            p
    unless eod
        0
    for p in proceeding
        if p.dtype is \exmotion
            [ex] = [e for e in exmotion when p.summary - /^.*?，/ -  /((，|。)是否有當)?，請公決案。/ is e.summary - /((，|。)是否有當)?，請公決案。/]
            unless ex
                [ex] = [e for e in exmotion when p.summary.indexOf(e.proposer - /，/) is 0]
            p.ref = ex
            console.log \unmatched p unless ex
        if p.dtype is \default
            unless p.origItem
                [a] = [a for a in agenda when p.summary.indexOf(a.summary) isnt -1]
                p.origItem = a.item if a

            if p.origItem
                p.ref = [a for a in agenda when a.item is p.origItem]
                inAgenda.push p unless p in inAgenda

    for a in agenda when a.item not in proceeding.map (.origItem)
        console.log a
    unhandled = items - inAgenda.length
    console.log {eod, items, unhandled}
    console.log \missing/extra items - unhandled + exmotion.length - proceeding.length
    console.log [p for p in proceeding when !p.ref]

    cb proceeding

#ly.forGazette gazette, (id, g, type, entries, files) ->
#    return if ad and g.ad !~= ad
#    return if type isnt \院會紀錄
#    return if g.sitting != 9
#    populate g
#

prepare_announcement = (g, cb) ->
    agenda <- getItems g, \agenda \Announcement
    proceeding <- getItems g, \proceeding \Announcement
    by_id = {[id, a] for {id}:a in agenda}
    for res, i in proceeding => let res, i
        res.origItem = by_id[res.id].item
        res.status = match res.result ? ''
        | ''              => \accepted
        | /照案通過/      => \accepted
        | /提報院會/      => \accepted
        | /列席報告/      => \accepted
        | /同意撤回/      => \revoked
        | /逕付(院會)?二讀/ => \prioritized
        | /黨團協商/      => \consultation
        | /交(.*)委員會/  => \committee
        | /中央政府總預算案/  => \committee
        | /展延審查期限/  => \extended
        | /退回程序委員會/ => \rejected
        | otherwise => res.result
        # XXX: misq has altered agenda in agenda query result.  we need to
        # extract this info from gazette
        #if res.origItem isnt res.item
            #console.log "#{res.origItem} -> #{res.item}"
    cb proceeding

require! mongoose
mongoose.connect('mongodb://localhost/ly');
console.log \cn

for sitting in [1 to 13] when sitting is 9 => let sitting
    g = {ad: 8, session: 1, sitting}
    funcs.push (done) ->
        ann <- prepare_announcement g
        resolution = {}
        for res in ann
            resolution[res.status] ?= 0
            ++resolution[res.status]
        misc = [p for p in ann when p.status is /決定/]
        console.log \misc misc if misc.length

        console.log ann

        motions = []
        funcs = ann.map (a) -> (next) ->
            err, bill, created <- Bill.findOrCreate do
                billNo: a.id
                proposer: {government: a.proposer}
                summary: a.summary
            motions.push do
                bill: [bill]
                resolution: a.result
                item: a.item
                agendaItem: a.origItem
            next!

        err, res <- async.waterfall funcs
        console.log \ok, motions.length
        A = new Announcement do
            sitting: g
            items: motions
        err <- A.save
        console.log \save err

        return done!
        motions <- prepare_motions g

        console.log {ys: g, ann_res: resolution, motions}

        done!

err, res <- async.waterfall funcs
console.log \ok, res
mongoose.connection.close!

