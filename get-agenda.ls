require! <[printf cheerio request fs zhutil ./lib/util]>
processItems = (body, entry) ->
    $ = cheerio.load body
    $('#queryListForm table tr').each ->
        [id] = @find "td a" .map -> @attr \onclick
            .map -> it.match /queryDetail\('(\d+)'\)/ .1
        # XXX: for discussion heading is _NOT_ part of content

        cols = @find \td .map -> @.text!
            .map -> it - /^\s*/mg
        return unless cols.length
        entry id, cols

parseAgenda = (body, doctype, type, cb) ->
    prevHead = null
    processItems body, (id, entry) ->
        # XXX: extract resolution.  the other info can be found using
        # getDetails with id
        if type is \Announcement
            console.log entry
            [heading, proposer, summary, result] = entry.0 / "\n"
            [_, zhitem]? = heading.match util.zhreghead
            console.log zhutil.parseZHNumber zhitem
            console.log proposer, summary
            console.log \===> result
        if type is \Discussion
            [heading, content] = entry
            heading -= /\s*/g
            heading = prevHead unless heading.length
            [sub, proposer, summary] = content / "\n"
            console.log heading
            [_, zhitem]? = heading.match util.zhreghead
            console.log zhutil.parseZHNumber zhitem
            console.log \==== sub, proposer
            console.log summary

        prevHead := heading if heading

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

#<- getAgenda {ad: 8, session: 2, sitting: 13}

require! optimist

data = fs.readFileSync optimist.argv._.0

<- parseAgenda data, \proceeding, \Discussion
