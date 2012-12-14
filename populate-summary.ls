require! \./lib/ly
require! <[optimist mkdirp fs async cheerio ./lib/util]>

{gazette, ad, lodev, type, force} = optimist.argv

err <- mkdirp "source/summary"
funcs = []

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
            console.log \nn entry
            [heading, proposer, summary, result] = entry.0 / "\n"
            [_, zhitem]? = heading.match util.zhreghead
            console.log util.parseZHNumber zhitem
            console.log proposer, summary
            console.log \===> id, result
        if type is \Discussion
            [heading, content] = entry
            console.log \DIS heading,
            console.log ccontent
            return unless content
            heading -= /\s*/g
            heading = prevHead unless heading.length
            [sub, proposer, summary] = content / "\n"
            console.log heading
            [_, zhitem]? = heading.match util.zhreghead
            console.log util.parseZHNumber zhitem
            console.log \==== id, sub, proposer
            console.log summary

        prevHead := heading if heading

    cb \notyet


ly.forGazette gazette, (id, g, type, entries, files) ->
    return if ad and g.ad !~= ad
    return if type isnt \院會紀錄
    return if g.sitting != 9
    for type in <[Announcement Discussion]> => let type
        file = "source/summary/#{g.ad}-#{g.session}-#{g.sitting}-#{type}.html"
        funcs.push (done) ->
            extract = (body) ->
                console.log g, type
                <- parseAgenda body, \proceeding, type
                console.log it
                done!


            _, {size}? <- fs.stat file
            if size
                extract fs.readFileSync file
            else
                body <- ly.getSummary g, \proceeding, type

                fs.writeFileSync file, body
                extract body
err, res <- async.waterfall funcs
console.log \ok, res
