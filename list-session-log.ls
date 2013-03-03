require! {optimist, fs, path, printf}
require! \./lib/ly
{committees} = require \./lib/util

{dir} = optimist.argv

by-committee = {}

err, files <- fs.readdir dir
for f in files when fs.statSync "#dir/#f" .isDirectory!
    primary = f.split \- .0
    by-committee[primary] ?= []
        ..push f

for primary, all of by-committee
    console.log "# #{committees[primary]}委員會"
    console.log """<img src="http://avatars.io/50a65bb26e293122b0000073/committee-#{primary}?size=large">"""
    for full in all
        names = full.split \-
        meetings = fs.readdirSync "#dir/#full" .filter -> it is /\.txt$/
        meetings = meetings.map -> +(it - /\.txt$/) 
        if names.length > 1
            console.log "### 聯席:"
            for it in names[1 to -1]
                console.log """<img src="http://avatars.io/50a65bb26e293122b0000073/committee-#{it}?size=small">"""
                console.log committees[it] + '委員會'
        max = Math.max ...meetings
        meetings.sort (a, b) -> a - b
        links = for i in [1 to max]
            if i in meetings
                "[#i](#full/#i.txt)"
            else
                "#i"
        console.log "\n會議記錄"
        console.log links.join ' '

    console.log '* * *'

console.log "[Icon attribution](http://ly.g0v.tw.jit.su/#/about)"
