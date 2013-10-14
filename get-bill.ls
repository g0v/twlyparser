require! \./lib/ly
require! <[optimist async]>

{dir} = optimist.argv

funcs = for id in optimist.argv._ => let id
  (done) ->
    info <- ly.misq.getBill id, {dir}
    <- ly.misq.ensureBillDoc id, info
    done!

<- async.waterfall funcs
console.log \done
