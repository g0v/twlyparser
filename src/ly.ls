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

getSummary = ({ad, session, sitting}, doctype, type, cb) ->
    uri = match doctype
    | \agenda     => 'http://misq.ly.gov.tw/MISQ/IQuery/queryMore5003vData.action'
    | \proceeding => 'http://misq.ly.gov.tw/MISQ/IQuery/queryMoreBillData.action'

    catalogType = match type
    | \Announcement => 1
    | \Discussion => 2
    | \Exmotion => 3

    throw \invliad if type is \Exmotion and doctype is \proceeding

    [term, sessionPeriod, sessionTimes] = [ad, session, sitting].map -> printf \%02d it
    err, res, body <- request do
        method: \POST
        uri: uri
        headers: do
            Origin: 'http://misq.ly.gov.tw'
            Referer: 'http://misq.ly.gov.tw/MISQ/IQuery/queryMore5003vData.action'
            User-Agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.17 (KHTML, like Gecko) Chrome/24.0.1312.5 Safari/537.17'
        form: {term, sessionPeriod, sessionTimes, catalogType, specialTimesRadio: \on}

    cb body

module.exports = { forGazette, index, gazettes, getSummary, getAgenda, getProceeding }
