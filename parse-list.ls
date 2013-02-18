require! {cheerio, optimist, fs}

{_:files} = optimist.argv

gazettes = try require \./data/gazettes
entries = try require \./data/index

parseTWDate = ->
    [_, y, m, d] = it.match /(\d+)\/(\d+)\/(\d+)/
    new Date +y + 1911, +m-1, +d

files.forEach (file) ->
    [_, gazette] = file.match /(\d+)/
    if gazettes[gazette]?
        console.error "#gazette already exists.  skipping"
        return
    data = fs.readFileSync file, \utf8
    date = null
    $ = cheerio.load data
    $ \table .find 'tr[id^=searchResult]' .each ->
        [_, type, summary, _, _, _, date?] = @.find \td .map -> @.text! - /^\s+|[\.\s]+$/g
        $(@)find 'input[value=原始檔]' .each ->
            [year, vol, book, seq] = @.attr 'onclick' .match /(\d+)/g
            ref = {year, vol, book, seq}
            gazettes[gazette] ?= { year, vol, date: parseTWDate date }
            entries.push {gazette, book, seq, type, summary }
            #return
            # the html is converted with word.  use unoconv instead
            #getFileList ref, id, \html
            #<- getFileList ref, gazette, \doc
            #console.log it

fs.writeFileSync \data/gazettes.json JSON.stringify gazettes, null, 4
fs.writeFileSync \data/index.json JSON.stringify entries, null, 4
