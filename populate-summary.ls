require! \./lib/ly
require! <[optimist async]>
require! <[./lib/misq]>

{ad=8, session=3, extra=null, sittingRange="1:15", agenda-only} = optimist.argv

funcs = []

parseProposer = (text) -> {text} <<< match text
| /本院(.*)黨團/ => caucus: [that.1] # XXX split
| /本院(.*)委員會/ => committee: [that.1] # XXX split
| otherwise => { government: text }
#| /本院委員(.*)等/ => { mly_primary: [that.1] } # XXX split

results = []
[start, end] = sittingRange.split \:

for sitting in [+start to +end] when sitting >0 => let sitting
    g = {ad, session, sitting, extra}
    funcs.push (done) ->
        results.push
        {announcement, discussion} <- misq.get g, {agenda-only}
        results.push {sitting: g, announcement, discussion}
        done!
err, res <- async.waterfall funcs
console.error \ok, res

console.log JSON.stringify results, null 4
