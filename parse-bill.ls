require! \./lib/ly
require! <[optimist path fs ./lib/util]>

{dir} = optimist.argv
id = optimist.argv._

err, res <- ly.misq.parse-bill-doc id, {+lodev, dir}
console.log err if err
console.log res if res
