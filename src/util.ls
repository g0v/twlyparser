/* helper of zh numbers, datetime */

zhnumber = <[○ 一 二 三 四 五 六 七 八 九 十]>

zhmap = {[c, i] for c, i in zhnumber}
zhreg = new RegExp "^((?:#{ zhnumber * '|' })+)、(.*)$", \m

intOfZHNumber = -> 
    if it in zhnumber 
    then parseZHNumber it
    else +it

parseZHHour = -> 
    [am_or_pm, hour] = it
    hour = parseInt hour
    if am_or_pm == '上午'
    then hour
    else hour + 12

parseZHNumber = ->
    if it.0 is \十
        l = it.length
        return 10 if l is 1
        return 10 + parseZHNumber it.slice 1
    if it[*-1] is \十
        return 10 * parseZHNumber it.slice 0, it.length-1
    res = 0
    for c in it when c isnt \十
        res *= 10
        res += zhmap[c]
    res

/* 
dateOfLyDateTime :: [String] -> [String] -> Date 

example:
console.log dateOfLyDate ['11', '10', '13'] ["下午", "10"]
*/
datetimeOfLyDateTime = (lydate, lyhour, lysec) -> 
    s = if lysec
      then lysec
      else 0
    h = if lyhour
      then parseZHHour lyhour
      else 0
    [y, m, d] = lydate.map -> intOfZHNumber it
    new Date +y + 1911, +m-1, d, h, s

module.exports = {datetimeOfLyDateTime, intOfZHNumber, parseZHNumber, zhreg, zhnumber}
