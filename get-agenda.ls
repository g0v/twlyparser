require! <[printf cheerio request ./lib/util]>

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
        form: {term, sessionPeriod, sessionTimes, catalogType: 1 specialTimesRadio: \on}

    $ = cheerio.load body
    $('#queryListForm table tr').each ->
        [id] = @find "td a" .map -> @attr \onclick
            .map -> it.match /queryDetail\('(\d+)'\)/ .1
        # XXX: for discussion heading is _NOT_ part of content
        [heading, content] = @find \td .map -> @.text!

        # XXX: extract resolution.  the other info can be found using
        # getDetails with id
        return unless heading
        console.log id
        console.log \h heading, \content content

    cb \notyet


getDetails = (id, cb) ->
    err, res, body <- request do
        method: \POST
        uri: 'http://misq.ly.gov.tw/MISQ/IQuery/misq5000QueryBillDetail.action'
        headers: do
            Origin: 'http://misq.ly.gov.tw'
            Referer: 'http://misq.ly.gov.tw/MISQ/IQuery/queryMoreBillData.action'
            User-Agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.17 (KHTML, like Gecko) Chrome/24.0.1312.5 Safari/537.17'
        form: { billNo: id }

    cb \notyet

<- getAgenda {ad: 8, session: 2, sitting: 13}
