require! <[chute fs crypto exec-sync]>
chute-map = try require \./data/chute-map
chute-map ?= {}
client = new chute
client.set require \./chuteConf

filename = require \optimist .argv._.0
err, buffer <- fs.readFile filename
md5 = crypto.createHash('md5').update(buffer).digest('hex')
size = buffer.length
files = [{ filename, size, md5 }]
chutes = []

if [id, shortcut]? = chute-map[filename]
    console.log "//media.getchute.com/media/#shortcut"
    return

err, {ids, shortcuts} <- client.uploads.upload { files, chutes }
[id] = ids
[shortcut] = shortcuts
chute-map[filename] = [id, shortcut]
console.log "//media.getchute.com/media/#shortcut"

fs.writeFileSync \data/chute-map.json JSON.stringify chute-map, null, 4
