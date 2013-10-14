require! \./lib/ly
require! <[optimist path fs ./lib/util]>

{dir} = optimist.argv
id = optimist.argv._

res <- ly.misq.parse-bill-doc id, {+lodev, dir}
console.log res
