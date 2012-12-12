require! <[github optimist async]>
require! \./lib/ly
require! \./data/chute-map

{gazette, ad, dir = '.', force} = optimist.argv

gh = new github version: \3.0.0
gh.authenticate require \./githubConf
issue-map = {}

get-all-pages = (param, cb) ->
    next = (paging) ->
        for {title}:issue in paging
            if title is /gazette (\d+)/
                issue-map[that.1] = issue

        if gh.hasNextPage paging
            console.log \nextpage
            gh.getNextPage paging, (err, res) -> next res
        else
            cb paging.meta

    gh.issues.repoIssues param, (err, res) ->
        next res


<- get-all-pages user: \g0v, repo: \ly-gazette, labels: \OCR, per_page: 100
meta <- get-all-pages user: \g0v, repo: \ly-gazette, labels: \OCR, per_page: 100, state: \closed
console.log meta

funcs = []

ly.forGazette gazette, (id, g, type, entries, files) ->
    return if type isnt /院會紀錄/
    if ad is \empty
        console.log \checking id, g.sitting
        return if g.sitting?
    else
        return if ad and g.ad !~= ad

    if !force and issue-map[id]
        return

    images = ["#name:\n![#name](//media.getchute.com/media/#{s})" for name, [_, s] of chute-map when 0 is name.indexOf "source/#id/"]
    return unless images.length


    source = for book of { [book,true] for {book} in entries }
        "* http://lci.ly.gov.tw/LyLCEW/communique#{if +g.year > 100 => '1' else ''}/final/pdf/#{g.year}/#{g.vol}/LCIDC01_#{g.year}#{g.vol}#{book}.pdf"

    body = "OCR Instructions: https://github.com/g0v/ly-gazette/wiki/OCR\n\n" + "If the image is not displayed, check the source pdf at:\n\n" + source * "\n" + "\n\nagainst current extracted source: https://raw.github.com/g0v/ly-gazette/master/raw/#{id}.md\n\n" + images * "\n"
    funcs.push (done) ->
        console.log id, issue-map[id]?number, images.length
        param = do
            user: \g0v
            repo: \ly-gazette
            labels: <[OCR]>
            body: body
            title: "gazette #id - #{images.length} images"

        param.labels.push \meta unless g.sitting?
        if issue = issue-map[id]
            method = \edit
            param <<< {issue.number, labels: issue.labels}
        else
            method = \create
        err, res <- gh.issues[method] param
        console.log res.title
        done!

err, res <- async.waterfall funcs
console.log \ok, res
