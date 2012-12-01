require! {AIO: 'avatars.io', fs, request, crypto, async, optimist, mkdirp}

{argv} = optimist

{AIO.accessToken, AIO.appId, member, skip} = argv

throw 'access token required' unless AIO.accessToken
throw 'appid required' unless AIO.appId

member ?= 8

members = require "./data/mly/#member"

err <- mkdirp "tmp"

fetchimg = (uri, filename, cb) ->
    file = fs.createWriteStream filename
    request.get(uri).pipe(file)
    file.on \close cb

funcs = members.map ({pic: uri}:m) -> (done) ->
    name = m.姓名 - /[a-zA-Z\s．]/g
    console.log name, uri
    filename = "tmp/#name.jpg"
    upload = ->
        key = crypto.createHash('md5').update("MLY/#name", \utf8).digest('hex')
        err, url <- AIO.upload filename, key
        console.log name, url
        done!

    _, {size}? <- fs.stat filename
    if size
        return done! if skip
        upload!
    else
        fetchimg uri, filename, upload
    return if size?

err, res <- async.waterfall funcs
console.log \ok, res
