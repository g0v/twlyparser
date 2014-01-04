require! {fs, zhutil}
/* helper of zh numbers, datetime */

export zhnumber = <[○ 一 二 三 四 五 六 七 八 九 十]>

zhmap = {[c, i] for c, i in zhnumber}
export zhreghead = new RegExp "^((?:#{ (<[千 百 零]> ++ zhnumber) * '|' })+)、(.*)$", \m
export zhreg = new RegExp "^((?:#{ zhnumber * '|' })+)$"

export intOfZHNumber = ->
    if it?match? zhreg
    then zhutil.parseZHNumber it
    else +it

parseZHHour = ->
    [am_or_pm, hour] = it
    hour = parseInt hour
    if am_or_pm == '上午'
    then hour
    else hour + 12

/*
dateOfLyDateTime :: [String] -> [String] -> Date

example:
console.log dateOfLyDate ['11', '10', '13'] ["下午", "10"]
*/
export datetimeOfLyDateTime = (lydate, lyhour, lysec) ->
    s = if lysec
      then lysec
      else 0
    h = if lyhour
      then parseZHHour lyhour
      else 0
    [y, m, d] = lydate.map -> intOfZHNumber it
    new Date +y + 1911, +m-1, d, h, s

export fixup = require \./charmap .applymap

export readFileSync = (path) -> fixup fs.readFileSync path, \utf8

update_one_to_many_map = (dct, k, v) ->
    if dct[k] is void
        dct[k] = [v]
    else unless v in dct[k]
        dct[k].push v
    dct

export build_people_interp_map = (ref_id, data, base_dct) ->
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

export nameListFixup = (names) ->
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


export committees = do
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
    DIS: \紀律
    CON: \修憲
    EXP: \經費稽核
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

export parseCommittee = (name) ->
    name.split /、/ .map ->
        [code]? = [code for code, name of committees when name is it]
        throw it+JSON.stringify(committees) unless code
        code

export convertDoc = (file, {success, error}) ->
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

{XRegExp} = require \xregexp

sitting_name = XRegExp """
    立法院(?:第(?<ad> \\d+)屆?第(?<session> \\d+)會期
      (?:第(?<extra> \\d+)次臨時會)?)?
    (?:
      第(?<sitting> \\d+)次(?<talk> 全院委員談話會?)?(?<whole> 全院委員會(?:(?<hearing>.*?)公聽會)?)?會議?
      |
      (?<committee>\\D+?)[兩二三四五六七八2-8]?委員會
        (?:
          第?(?<committee_sitting> \\d+)次(?:全體委員|聯席)會?會議?
        |
          (?:舉行)?(?<committee_hearing> .*?公聽會(?:[（\\(]第(?<hearing_sitting> .*?)場[）\\)])?.*?)(?:會議)?
        )
      |
      (?<talk_unspecified> 全院委員談話會(?:會議)?)
      |
      (?<election> 選舉院長、副院長會議)
      |
      (?<consultation>黨團協商會議)
    )
  """, \x

export function get-sitting(name)
  sitting = XRegExp.exec name, sitting_name
  return unless sitting
  if sitting.committee
    sitting.committee = parseCommittee sitting.committee
    sitting.sitting = sitting.committee_sitting
  if sitting.whole
    sitting.committee = <[WHL]>
  if sitting.talk_unspecified
    sitting.talk = 1
    sitting.sitting = 1
  if sitting.talk
    sitting.committee = <[TLK]>
  if sitting.hearing
    [_, sitting.hearing]? = that.match /「(.*?)」/
  else if sitting.committee_hearing
    [_, sitting.hearing]? = that.match /「(.*?)」/
    sitting.sitting = zhutil.parseZHNumber sitting.hearing_sitting if sitting.hearing_sitting

  for _ in <[ad session sitting extra]> => sitting[_] = +sitting[_] if sitting[_]
  sitting
