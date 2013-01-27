global <<< require \prelude-ls
require! {fs, optimist}

{dir = '.'} = optimist.argv
#dir = \../ly-gazette/raw
output = []

find = (depth, serial, json) ->
    return if not json or typeof json != \object

    if json.length == void and typeof json == \object
        for key, content of json
            find depth+1, serial, content
        return

    for content in json
        approval = content.approval
        veto     = content.veto
        if not veto and approval
            console.log "#serial depth:#depth approval:#{approval.length} no veto warning"
        if not approval and veto
            console.log "#serial depth:#depth veto:#{veto.length} no approval warning"
        if approval or veto
            approval ?= []
            veto     ?= []
            console.log serial, depth, approval.length, veto.length
            output.push "#serial,#{approval.join \|},#{veto.join \|}"
        else
            find depth+1, serial, content


list = filter ( == /\.json$/i ), fs.readdirSync dir
#list = [ \3109.json ]

for filename in list
    json = require "#dir/#filename"
    serial   = (filename / \.)[0]
    find 0, serial, json.data[0].data
    #fs.writeFileSync "#dir/#serial.csv", output.join "\n"
    #output = []

console.log "output : #dir/vote.csv"
fs.writeFileSync "#dir/vote.csv", output.join "\n"

