require! {optimist, fs, path, printf}
require! \./lib/ly

grouped = {}

ly.forGazette {}, (id, g, type, entries, files) ->
    return if type isnt /院會紀錄/
    return if g.secret
    {ad, session, sitting, extra} = g
    return unless ad
    name = printf "立法院第 %d 屆第 %d 會期第 %2d 次會議紀錄", ad, session, sitting
    grouped.{}[ad].[][session].push {id} <<< g

ads = [k for k of grouped].sort (a, b) -> b - a
for ad in ads => let sessions = grouped[ad]
    console.log "# 第 #ad 屆"
    s = [k for k of sessions].sort (a, b) -> b - a
    for session in s => let sittings = sessions[session]
        console.log "## 第 #session 會期"

        links = sittings.map ({extra,id,sitting}) ->
            name = if extra => "(第#{extra}次臨時會)" else ''
            name += "#sitting"
            "[#{name}](#{id}.md)"
        .join ' '
        console.log "### 院會 #links"
        console.log "純文字" + links.replace /\.md/g, '.txt'
        console.log "\n"
    console.log "\n***\n"
