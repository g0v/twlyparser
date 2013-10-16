require! \./lib/ly
require! <[optimist async]>

{dir} = optimist.argv

funcs = for id in optimist.argv._ => let id
  (done) ->
    info <- ly.misq.getBill id, {dir}
    err <- ly.misq.ensureBillDoc id, info
    console.log id, err if err
    done!

<- async.waterfall funcs
console.log \done
