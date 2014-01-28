export index = require \../data/index
export gazettes = require \../data/gazettes
require! <[printf request]>

export function forGazette (opts, cb)
    unless typeof opts is \object
        opts = { gazette: opts }
    for id, g of gazettes when !opts.gazette? || id ~= opts.gazette => let id, g
        entries = [i for i in index when i.gazette ~= id]
        if opts.type
            entries .= filter -> it.type is opts.type
        bytype = {}
        for {type}:i in entries
            (bytype[type] ||= []).push i
        for type, entries of bytype
            allfiles = [uri for uri of {[x,true] \
                for x in entries.map(-> it.files ? []).reduce (++)}]
            cb id, g, type, entries, allfiles

export getAgenda = (meta, type, cb) ->
    getSummary meta, \agenda, type, cb

export getProceeding = (meta, type, cb) ->
    getSummary meta, \proceeding, type, cb

export getBillDetails = (id, cb) ->
    uri = "http://misq.ly.gov.tw/MISQ/IQuery/misq5000QueryBillDetail.action"

    err, res, body <- request do
        method: \POST
        uri: uri
        headers: do
            Origin: 'http://misq.ly.gov.tw'
            Referer: uri
            User-Agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.17 (KHTML, like Gecko) Chrome/24.0.1312.5 Safari/537.17'
        form: { billNo: id }

    cb body

export getMeetings = (queryCondition, cb) ->
    uri = 'http://misq.ly.gov.tw/MISQ/IQuery/misq5000QueryMeeting.action'
    # term = ad
    err, res, body <- request do
        method: \POST
        uri: uri
        headers: do
            Origin: 'http://misq.ly.gov.tw'
            Referer: uri
            User-Agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.17 (KHTML, like Gecko) Chrome/24.0.1312.5 Safari/537.17'
        form: do
            queryCondition: <[ 0703 2100 2300 2400 4000 4100 4200 4300 4500 ]>
            term: ''
            sessionPeriod: ''
            meetingDateS: ''
            meetingDateE: ''
    cb body

export getSummary = ({ad, session, sitting, extra}, doctype, type, cb) ->
    uri = match doctype
    | \agenda     => 'http://misq.ly.gov.tw/MISQ/IQuery/queryMore5003vData.action'
    | \proceeding => 'http://misq.ly.gov.tw/MISQ/IQuery/queryMoreBillData.action'

    catalogType = match type
    | \Announcement => 1
    | \Discussion => 2
    | \Exmotion => 3

    throw "invliad #type #doctype" if type is \Exmotion and doctype is \proceeding

    [term, sessionPeriod, sessionTimes] = [ad, session, sitting].map -> printf \%02d it
    if extra
      # really, WTF
      meetingTimes = sessionTimes
      sessionTimes = printf \%02d extra
    err, res, body <- request do
        method: \POST
        uri: uri
        headers: do
            Origin: 'http://misq.ly.gov.tw'
            Referer: 'http://misq.ly.gov.tw/MISQ/IQuery/queryMore5003vData.action'
            User-Agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.17 (KHTML, like Gecko) Chrome/24.0.1312.5 Safari/537.17'
        form: {term, sessionPeriod, sessionTimes, meetingTimes, catalogType, specialTimesRadio: \on, fromQuery: \Y}

    cb body

export getCalendarEntry = (id, cb) ->
    err, res, body <- request do
        method: \GET
        uri: "http://www.ly.gov.tw/01_lyinfo/0109_meeting/meetingView.action?id=#id"
        headers: do
            Origin: 'http://www.ly.gov.tw/01_lyinfo/0109_meeting/meetingView.action'
            Referer: 'http://www.ly.gov.tw/01_lyinfo/0109_meeting/meetingView.action'
            User-Agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.17 (KHTML, like Gecko) Chrome/24.0.1312.5 Safari/537.17'

    $ = require \cheerio .load body
    var prev
    res = {}
    header-map = do
        屆別: \ad
        會期: \session
        日期時間: \datetime
        召集委員: \chair
        主審委員會: \committee
        聯席委員會: \cocommittee
        會議室: \room
        會議名稱: \name
        會議事由: \agenda
        說明: \remark

    $('td > div.page_content_date,div.page_content_body').each ->
        if !@hasClass \page_content_body and [_, header, content]? = @text!match /^(.{2,9}?)：([\s\S]*)$/m
            unless content
                prev := header
                return
        else
            header = prev ? \unknown
            prev := null
            content = if @hasClass \page_content_body
                $ '<div/>' .html(@html!replace /<br>/g '\n').text!
            else
                @text!
        if @hasClass \page_content_date
            content .= replace /\s+/g ' '
        res[header-map[header] ? header] = content - /^\s*|\s*$/g

    cb res

export fetchCalendarPage = ({uri, params, page=1, last-page, seen}, done) ->
    require! <[qs cheerio]>
    return done [] if last-page and page > last-page
    thisuri = uri + '?' + qs.stringify params <<< {'d-49489-p': page}
    err, res, body, cache <- request.get thisuri, {
        headers: do
            Origin: 'http://www.ly.gov.tw/01_lyinfo/0109_meeting/meetingView.action'
            Referer: 'http://www.ly.gov.tw/01_lyinfo/0109_meeting/meetingView.action'
            User-Agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.17 (KHTML, like Gecko) Chrome/24.0.1312.5 Safari/537.17'
        }
    $ = cheerio.load body

    results = $ 'table.news_search tbody tr' .map ->
        [date, time, committee, summary, room] = @find 'td' .map -> @text! - /^\s*|\s*$/g
        [id] = @find 'a[href]' .map -> @attr \href .match /id=(\d+)/ .1
        {id, date, time, committee, summary, room}


    if seen and [id for {id} in results when id ~= seen].length
        return done results.filter -> +it.id > seen

    if page is 1
        [_, entries] = $ 'div.pagelinks, div.total' .text!match /共\s*(\d+)\s*筆資料/
        last-page := Math.ceil entries/30
    res <- fetchCalendarPage {uri, params, page: page+1, last-page, seen}
    done results ++ res

export getCalendarByYear = (year, seen, cb) ->
    entries <- fetchCalendarPage do
        uri: 'http://www.ly.gov.tw/01_lyinfo/0109_meeting/meetingList.action'
        seen: seen
        params: do
            order: \DESC
            eDate: "#{year}12"
            sDate: "#{year}01"
    cb entries

export function getLiveStatus(cb)
  ivod-banner-hash =
    14: \YS #\院會
    10: \IAD #\內政
    11: \FND #\外交及國防
    8 : \ECO #\經濟
    1 : \FIN #\財政
    13: \EDU #\教育及文化
    9 : \TRA #\交通
    12: \JUD #\司法與法制
    6 : \SWE #\社會福利及衛生環境
    7 : \PRO #\程序
    2 : \DIS #\紀律
    3 : \CON #\修憲

  ivod-channel-from-banner = (ivod-banner-hash.)

  p = /menu_([a1])_(\d+)\.jpg/g
  s = {}
  (e,r,b) <- request "http://ivod.ly.gov.tw/new_live.jsp"
  while [_, _class, id]? = p.exec b
    s[ivod-channel-from-banner id] = {live: _class is \a, chbid: id}
  cb s


export util = require \./util
export misq = require \./misq
export lci = require \./lci
