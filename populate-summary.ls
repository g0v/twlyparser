require! \./lib/ly
require! <[optimist mkdirp fs async cheerio ./lib/util]>

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
                | /^[^，]+臨時提案/ => 'exmotion'
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
        console.log g, type
        parseAgenda g, body, doctype, type, cb

    _, {size}? <- fs.stat file
    if size
        extract fs.readFileSync file
    else
        body <- ly.getSummary g, doctype, type

        fs.writeFileSync file, body
        extract body

#ly.forGazette gazette, (id, g, type, entries, files) ->
#    return if ad and g.ad !~= ad
#    return if type isnt \院會紀錄
#    return if g.sitting != 9
#    populate g
#
for sitting in [1 to 13] => let sitting
    g = {ad: 8, session: 1, sitting}
    funcs.push (done) ->
        agenda <- getItems g, \agenda \Announcement
        proceeding <- getItems g, \proceeding \Announcement
        resolution = {}
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
            #if res.origItem isnt res.item
                #console.log "#{res.origItem} -> #{res.item}"
            resolution[res.status] ?= 0
            ++resolution[res.status]
        console.log \rej [p for p in proceeding when p.status is /決定/]
        console.log resolution


        return done!

        agenda <- getItems g, \agenda \Discussion
        exmotion <- getItems g, \agenda \Exmotion
        proceeding <- getItems g, \proceeding \Discussion
        eod = no
        items = Math.max ...agenda.map (.item)
        [eod] = [p.origItem ? p.item for p in proceeding when p.eod]
        inAgenda = [p for p in proceeding when p.origItem]
        if eod and !inAgenda.length # unaltered but unfinished
            inAgenda = [p for p in proceeding when p.item <= eod]
        unhandled = if eod => items - inAgenda.length else 0
        console.log {eod, items, unhandled}
        console.log \missing/extra items - unhandled + exmotion.length - proceeding.length
        console.log [p for p in proceeding when p.dtype is \agenda]

        done!

err, res <- async.waterfall funcs
console.log \ok, res
