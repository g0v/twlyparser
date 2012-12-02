require! {optimist, fs, path, printf}
require! \./lib/ly

results = []

ly.forGazette null, (id, g, type, entries, files) ->
    return if type isnt /院會紀錄/
    {ad, session, sitting, extra} = g
    return unless ad
    name = printf "立法院第 %d 屆第 %d 會期第 %2d 次會議紀錄", ad, session, sitting
    name += "(臨時會)" if extra
    results.unshift {name,id}

results.forEach ({name,id}) -> console.log "[#{name}](#{id}.md) txt(#{id}.txt)\n"
