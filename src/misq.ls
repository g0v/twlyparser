require! \./ly
require! <[mkdirp fs cheerio printf ./util zhutil request]>

entryStatus = (res, def) -> match res
| /協商/    => \consultation
| /不予?通過/  => \rejected
| /通過/    => \passed
| /函請行政院研處/ => \ey
| /暫不予處理/ => \unhandled
| otherwise => def

export cache_dir = process.cwd! + "/source/misq"

export function get(s, {agenda-only, dir=cache_dir}, cb)
  err <- mkdirp dir
  throw err if err
  cache_dir := dir
  announcement <- prepare_announcement s, agenda-only
  discussion <- prepare_discussion s, agenda-only
  cb {announcement, discussion}

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
            unless summary
                [_, proposer, summary]? = proposer.match /^(.*?)(函送.*)$/
                unless summary
                  console.log \unknown proposer
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

getItems = (g, doctype, type, cb) ->
    sitting = if g.extra
        "T#{g.sitting}-#{g.extra}"
    else
        g.sitting
    file = "#cache_dir/#{g.ad}-#{g.session}-#{sitting}-#{doctype}-#{type}.html"
    json = file.replace /\.html$/, '.json'

    extract = (body) ->
        body = util.fixup body.toString \utf-8
        parseAgenda g, body, doctype, type, (res) ->
            fs.writeFileSync json, JSON.stringify res, null 4
            cb res

    _, {size}? <- fs.stat json
    if size
        return cb require json

    _, {size}? <- fs.stat file
    if size
        extract fs.readFileSync file
    else
        body <- ly.getSummary g, doctype, type

        fs.writeFileSync file, body
        extract body


prepare_announcement = (g, agenda-only, cb) ->
    agenda <- getItems g, \agenda \Announcement
    proceeding <- (if agenda-only => (,,,cb) -> cb [] else getItems) g, \proceeding \Announcement
    results = for a in agenda
        entry = {} <<< a
        entry.agendaItem = delete entry.item
        entry
    by_id = {[id, a] for {id}:a in results}

    for {id,result,item} in proceeding
        unless entry = by_id[id]
          console.error "entry not found: #{id}"
          continue

        entry <<< {resolution: result, item}
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

prepare_discussion = (g, agenda-only, cb) ->
    agenda <- getItems g, \agenda \Discussion
    exmotion <- (if agenda-only => (,,,cb) -> cb [] else getItems) g, \agenda \Exmotion
    proceeding <- (if agenda-only => (,,,cb) -> cb [] else getItems) g, \proceeding \Discussion
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

extractNames = (content) ->
    unless [_, role, names]? = content.match /getLawMakerName\('(\w+)', '(.*)'\)/
        return []
    names .= replace /(?:^|\s)(\S)\s(\S)(?:\s|$)/g (...args) -> " #{args.1}#{args.2} "
    names .= replace /黨團/ '黨團 '
    mly = names.split /\s+/ .filter (.length)
    [{proposal: \sponsors, petition: \cosponsors}[role], mly]


parseBill = (id, body, cb) ->
    $ = cheerio.load body
    info = {extracted: new Date!}

    $ 'table[summary="院會審議消息資料表格"] tr' .each ->
        key = @find \th .map -> @text!
        if key.length is 1 and key isnt /國會圖書館/
            key = key.0 - /：/
            content = @find \td
            text = -> content.map(-> @text!).0
            [prop, value] = match key
            | /提案單位/ => [\propsed_by text!]
            | \審查委員會 =>
                text!match /^本院/
                if text!match /^本院(.*?)(?:兩|三|四|五|六|七|八)?委員會$/
                    [\committee util.parseCommittee that.1]
                else
                    [\propser_text text!]
            | \議案名稱 => [\summary text!]
            | \提案人 => extractNames content.html!
            | \連署人 => extractNames content.html!
            | \議案狀態 => [\status text! - /^\s*|\s*$/g]
            | \關連議案 =>
                related = content.find \a .map -> [
                    * (@attr \onclick .match /queryBillDetail\('(\d+)',/).1
                    * @text! - /^\s*|\s*$/g
                ]
                [\related, related]
            | \相關附件 =>
                doc = content.find \a .map ->
                    href = @attr \href
                    href .= replace /^http:\/\/10.12.8.14:28080\//, 'http://misq.ly.gov.tw/'
                    [ href.match(/(pdf|doc)/i).1.toLowerCase!, href ]
                [\doc, {[type, uri] for [type, uri] in doc}]
            | otherwise => [key, text!]
            info[prop] = value if prop
    cb info

export function getBill(id, {dir}, cb)
    cache_dir := dir if dir
    err <- mkdirp "#cache_dir/bills/#{id}"
    file = "#cache_dir/bills/#{id}/index.html"
    json = file.replace /\.html$/, '.json'

    extract = (body) ->
        parseBill id, body, (res) ->
            fs.writeFileSync json, JSON.stringify res, null 4
            cb res

    _, {size}? <- fs.stat json
    if size
        return cb require json

    _, {size}? <- fs.stat file
    if size
        extract fs.readFileSync file
    else
        body <- ly.getBillDetails id
        fs.writeFileSync file, body
        extract body

export function ensureBillDoc(id, info, cb)
    return cb! unless uri = info.doc.doc
    if uri is /http:\/\/10\./
        console.error id, uri
        return cb!
    file = "#cache_dir/bills/#{id}/file.html"
    _, {size}? <- fs.stat file
    return cb! if size?
    file = "#cache_dir/bills/#{id}/file.doc"
    _, {size}? <- fs.stat file
    return cb! if size?
    var statusCode
    writer = with fs.createWriteStream file
        ..on \error -> cb it
        ..on \close ->
          if statusCode isnt 200
            fs.unlinkSync file
            return cb statusCode
          console.info \done uri; cb!
        ..
    request {method: \GET, uri}, (_, res) -> statusCode := res.statusCode
    .pipe writer

export function parseBillDoc(id, opts, cb)
  {BillParser} = require \./parser
  cache_dir := opts.dir if opts.dir
  doit = ->
    parser = new BillParser {-chute}
    content = []
    bill = require "#cache_dir/bills/#{id}/index.json"
    parser.output-json = -> content.push it
    # XXX check duplicated
    push-field = (field, val) ->
      if bill[field]
        console.warn "#id contains multiple doc"
        bill.attachments = {}
      if bill.attachments
        bill.attachments[field] = val
      else
        bill[field] = val
        if field is \id and id isnt val
          console.warn "id mismatch: #id / #val"

    parser.output = (line) -> match line
    | /^案由：(.*)$/ => push-field \abstract, that.1
    | /^提案編號：(.*)$/ => push-field \bill_ref, that.1
    | /^議案編號：(.*)$/ => push-field \id, that.1
    | otherwise =>
    parser.base = "#cache_dir/bills/#{id}"

    try
      parser.parseHtml util.readFileSync file
    catch
      return cb e
    cb null bill <<< {content}

  file = "#cache_dir/bills/#{id}/file.html"

  _, {size}? <- fs.stat file
  return doit! if size

  util.convertDoc file.replace(/html$/, \doc), opts <<< do
    error: -> cb new Error it ? 'convert'
    success: doit
