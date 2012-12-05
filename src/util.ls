require! {fs}
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

fixup = ->
    it  .replace /\uE58E/g, '冲'
        .replace /\uE8E2/g, '堃'
        .replace /\uE8E4/g, '崐'
        .replace /\uE457/g, '堦'
        .replace /\uE5CF/g, '峯'
        .replace /\uE1BD/g, '%'

readFileSync = (path) -> fixup fs.readFileSync path, \utf8

update_one_to_many_map = (dct, k, v) ->
    if dct[k] is undefined
        dct[k] = [v]
    else unless v in dct[k]
        dct[k].push v
    dct

build_people_interp_map = (ref_id, data, base_dct) ->
    data.map ->
        meta = it.0
        if meta and meta.type is \interp
            meta.people.map ->
                update_one_to_many_map base_dct, it, ref_id
    base_dct

module.exports = {datetimeOfLyDateTime, intOfZHNumber, parseZHNumber, zhreg, zhnumber, readFileSync, build_people_interp_map}
