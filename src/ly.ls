require!  {index: \../data/index,gazettes: \../data/gazettes, printf, request}

function forGazette (gazette, cb)
    for id, g of gazettes when !gazette? || id ~= gazette => let id, g
        entries = [i for i in index when i.gazette ~= id]
        bytype = {}
        for {type}:i in entries
            (bytype[type] ||= []).push i
        for type, entries of bytype
            allfiles = [uri for uri of {[x,true] \
                for x in entries.map(-> it.files ? []).reduce (+++)}]
            cb id, g, type, entries, allfiles

getAgenda = (meta, type, cb) ->
    getSummary meta, \agenda, type, cb

getProceeding = (meta, type, cb) ->
    getSummary meta, \proceeding, type, cb

getBillDetails = (id, cb) ->
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


getMeetingAgenda = (meetingNo, cb) ->
    uri = "http://misq.ly.gov.tw/MISQ/IQuery/misq5000QueryMeetingDetail.action"

    err, res, body <- request do
        method: \POST
        uri: uri
        headers: do
            Origin: 'http://misq.ly.gov.tw'
            Referer: uri
            User-Agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.17 (KHTML, like Gecko) Chrome/24.0.1312.5 Safari/537.17'
        form: { meetingNo, meetingTime: \101/12/18 departmentCode: \0703 }

    cb body

getMeetings = (queryCondition, cb) ->
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
            term: \07
            sessionPeriod: ''
            meetingDateS: ''
            meetingDateE: ''
    cb body

getSummary = ({ad, session, sitting, extra}, doctype, type, cb) ->
    uri = match doctype
    | \agenda     => 'http://misq.ly.gov.tw/MISQ/IQuery/queryMore5003vData.action'
    | \proceeding => 'http://misq.ly.gov.tw/MISQ/IQuery/queryMoreBillData.action'

    catalogType = match type
    | \Announcement => 1
    | \Discussion => 2
    | \Exmotion => 3

    throw "invliad #type #doctype" if type is \Exmotion and doctype is \proceeding

    [term, sessionPeriod, sessionTimes] = [ad, session, sitting].map -> printf \%02d it
    meetingTimes = printf \%02d extra if extra
    err, res, body <- request do
        method: \POST
        uri: uri
        headers: do
            Origin: 'http://misq.ly.gov.tw'
            Referer: 'http://misq.ly.gov.tw/MISQ/IQuery/queryMore5003vData.action'
            User-Agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.17 (KHTML, like Gecko) Chrome/24.0.1312.5 Safari/537.17'
        form: {term, sessionPeriod, sessionTimes, meetingTimes, catalogType, specialTimesRadio: \on, fromQuery: \Y}

    cb body

module.exports = { forGazette, index, gazettes, getSummary, getAgenda, getProceeding, getMeetings, getMeetingAgenda, getBillDetails }
