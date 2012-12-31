require! {fs}
/* helper of zh numbers, datetime */

zhnumber = <[○ 一 二 三 四 五 六 七 八 九 十]>

zhmap = {[c, i] for c, i in zhnumber}
zhreghead = new RegExp "^((?:#{ (<[百 零]> +++ zhnumber) * '|' })+)、(.*)$", \m
zhreg = new RegExp "^((?:#{ zhnumber * '|' })+)$"

intOfZHNumber = ->
    if it?match? zhreg
    then parseZHNumber it
    else +it

parseZHHour = ->
    [am_or_pm, hour] = it
    hour = parseInt hour
    if am_or_pm == '上午'
    then hour
    else hour + 12

parseZHNumber = ->
    it .= replace /零/g, '○'
    it .= replace /百$/g, '○○'
    it .= replace /百/, ''
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

nameListFixup = (names) ->
    # Heuristic: merge two names if both are single words
    for i to names.length - 1
        if names[i]?.length == 1 and names[i+1]?.length == 1
            names[i] += names[i+1]
            names[i+1] = ''

    # Heuristic: split a long name into two with luck.  The data is wrong
    # back to doc->html phase. Here is a heuristic to make most cases work,
    # with exceptions like "李正宗靳曾珍麗" that require efforts to do
    # right (e.g. with a name dictionary).
    ret_names = []
    for name in names when name != ''
        if name.length == 6 and /‧/ != name
            ret_names.push name.substr(0, 3), name.substr(3, 3)
        else
            ret_names.push name
    ret_names


committees = do
    IAD: \內政
    FND: \外交及國防
    ECO: \經濟
    FIN: \財政
    EDU: \教育及文化
    TRA: \交通
    JUD: \司法及法制
    SWE: \社會福利及衛生環境

parseCommittee = (name) ->
    name.split /、/ .map ->
        [code]? = [code for code, name of committees when name is it]
        throw it+JSON.stringify(committees) unless code
        code

module.exports = {datetimeOfLyDateTime, intOfZHNumber, parseZHNumber, zhreg, zhreghead, zhnumber, readFileSync, build_people_interp_map, nameListFixup, committees, parseCommittee}
