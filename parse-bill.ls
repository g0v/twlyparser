require! \./lib/ly
require! <[optimist path fs ./lib/util]>

{dir} = optimist.argv
dir ?= ly.misq.cache_dir
id = optimist.argv._

res <- ly.misq.parse-bill-doc id, {+lodev}
console.log res
