require! {fs}
/* helper of zh numbers, datetime */

zhnumber = <[○ 一 二 三 四 五 六 七 八 九 十]>

zhmap = {[c, i] for c, i in zhnumber}
zhreghead = new RegExp "^((?:#{ (<[千 百 零]> ++ zhnumber) * '|' })+)、(.*)$", \m
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

fixup = require \./charmap .applymap

readFileSync = (path) -> fixup fs.readFileSync path, \utf8

update_one_to_many_map = (dct, k, v) ->
    if dct[k] is void
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

_global_name_cache = null

initNameCache =  ->
    # Not everyone is in mly-*.json. Until we have them, let's put some of them here directly.
    _global_name_cache := {[x, 1] for x in
        <[ 蔡英文 盧天麟 徐慶元 羅文嘉 瓦歷斯‧貝林
           何嘉榮 林宗男 楊秋興 朱立倫 李炷烽 ]>}
    for i from 2 to 8
        json = try require "../data/mly-#i.json"
        _global_name_cache <<< {[fixup(person.name), 1] for person in json}

nameListFixup = (names) ->
    initNameCache! if _global_name_cache == null
    ret_names = []
    unknown = ''
    word_stream = names * ''
    i = 0
    while i < word_stream.length
        for len from 2 to 10
            maybe_name = word_stream.substr(i, len)
            if maybe_name of _global_name_cache
                break
        if len == 10
            # try from the next charactor if not found
            unknown += word_stream[i]
            i++
        else
            # Our dictionary doesn't cover everybody, thus the tricky to pick up those missing.
            if unknown.length > 0
                ret_names.push unknown
                unknown = ''
            ret_names.push maybe_name
            i += len
    if unknown.length > 0
        ret_names.push unknown
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
    WHL: \全院
    PRO: \程序
    # obsolete
    IAP: \內政及民族
    IAF: \內政及邊政
    FRO: \邊政
    DEF: \國防
    FOR: \外交及僑務
    FOP: \外交及僑政
    OVP: \僑政
    DIP: \外交
    JUR: \司法
    LAW: \法制
    SCI: \科技及資訊
    ECE: \經濟及能源
    ESW: \衛生環境及社會福利
    ELB: \衛生環境及勞工
    BGT: \預算及決算
    BUD: \預算
    EDN: \教育

parseCommittee = (name) ->
    name.split /、/ .map ->
        [code]? = [code for code, name of committees when name is it]
        throw it+JSON.stringify(committees) unless code
        code

convertDoc = (file, {success, error}) ->
    require! shelljs
    # XXX: correct this for different OS
    python = process.env.UNOCONV_PYTHON ? match process.platform
    | \darwin => "/Applications/LibreOffice.app/Contents/MacOS/python"
    | otherwise => "/opt/libreoffice4.0/program/python"
    unless shelljs.which python
        throw "python for unoconv not found: #python. specify UNOCONV_PYTHON to override"
    cmd = "#python ../twlyparser/unoconv/unoconv -f html #file"
    p = shelljs.exec cmd, {+silent, +async}, (code, output) ->
        console.log \converted
        console.log output, code, p? if code isnt 0
        clear-timeout rv
        success!
    rv = do
        <- setTimeout _, 320sec * 1000ms
        console.log \timeout
        p.kill \SIGTERM
        p := null
        error!

module.exports = {datetimeOfLyDateTime, intOfZHNumber, parseZHNumber, zhreg, zhreghead, zhnumber, readFileSync, build_people_interp_map, nameListFixup, committees, parseCommittee, convertDoc}
