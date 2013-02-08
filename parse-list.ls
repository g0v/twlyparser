require! {cheerio, optimist, fs, printf}
require! \./lib/util
require! \./lib/util_hsiao

{_:files} = optimist.argv

gazettes = try require \./data/gazettes
if gazettes == void then gazettes = {}
entries = try require \./data/index
if entries == void then entries = []

entryListToHash = (entries) ->
    {[entryKey(val), val] for val in entries}

entries_hash = entryListToHash entries

entryKey = (entry) ->
    printf "%05d%s%02d%s", entry.gazette, entry.book, entry.seq, entry.type

parseTWDate = ->
    [_, y, m, d] = it.match /(\d+)\/(\d+)\/(\d+)/
    new Date +y + 1911, +m-1, +d

files.forEach (file) ->
    [_, gazette] = file.match /(\d+)/
    data = util_hsiao.readHtmlFileSync file, \utf8
    $ = cheerio.load data
    $ \table .find 'tr[id^=searchResult]' .each ->
        [_, type, summary, _, _, _, date?] = @.find \td .map -> @.text! - /^\s+|[\.\s]+$/g
        $(@)find 'input[value=原始檔]' .each ->
            [year, vol, book, seq] = @.attr 'onclick' .match /(\d+)/g
            ref = {year, vol, book, seq}
            the_gazette = if year == '98' && vol == '24' then '3710' else gazette
            console.log 'the_gazette:', the_gazette, 'year:', year, 'vol:', vol, 'seq:', seq, 'type:', type, 'summary:', summary
            gazettes[the_gazette] ?= { year, vol, date: parseTWDate date }
            entry = {gazette: the_gazette, book, seq, type, summary }
            entry_key = entryKey(entry)
            if entries_hash[entry_key]? then console.log '[WARNING] repeated:', entry_key else entries_hash[entry_key] = entry
            #return
            # the html is converted with word.  use unoconv instead
            #getFileList ref, id, \html
            #<- getFileList ref, gazette, \doc
            #console.log it

entries = [val for key, val of entries_hash]
fs.writeFileSync \data/gazettes.json JSON.stringify gazettes, null, 4
fs.writeFileSync \data/index.json JSON.stringify entries, null, 4
