charmap = do
  E007: \亘
  E00A: \吔
  E00C: \邨
  E013: \叁
  E018: \揑
  E01A: \咗
  E020: \枱
  E028: \珏
  E02B: \峯
  E03E: \啩
  E047: \鈎
  E048: \疴
  E057: \菓
  E05E: \綉
  E063: \蔴
  E077: \嚤
  E07A: \坂
  E080: \鉄
  E082: \鑛
  E083: \鱲
  E088: \酶
  E090: \却
  E092: \踪
  E094: \煊
  E096: \綫
  E09E: \牀
  E09F: \壳
  E0A7: \抝
  E0A9: \肽
  E0AD: \堃
  E0BC: \袜
  E0D6: \俤
  E0D7: \俥
  E0E1: \儎
  E0F1: \冲
  E107: \吡
  E10B: \咤
  E110: \喆
  E14E: \廍 
  E17B: \撐
  E1A8: \洤
  E1B0: \瀞
  E1BD: \％
  E1F4: \礮
  E233: \脇
  E240: \粦
  E241: \艢
  E247: \蟎
  E25C: \罸
  E270: \覇
  E282: \贌
  E2EF: \鰊
  E2F3: \鰮
  E2F6: \鰺
  E2F7: \嶋
  E306: \麯
  E30B: \竈
  E31E: \韮
  E320: \疴
  E322: \竈
  E32B: \碁
  E32C: \窻
  E33C: \俥
  E33D: \煊
  E355: \樫
  E371: \磘 
  E374: \胆
  E376: \碱
  E39F: \鰮
  E3A6: \鰊
  E3AD: \綉
  E3FB: \廍
  E42B: \癎
  E430: \瑠
  E447: \枱
  E44C: \礮
  E44F: \菓
  E450: \脇
  E457: \堦
  E45B: \栢
  E464: \亘
  E47C: \繮
  E486: \苷
  E48A: \萘
  E494: \蟎
  E498: \牀
  E4B3: \酶
  E4BE: \鐧
  E4EA: \鰺
  E557: \煅
  E57E: \鈎
  E581: \銹
  E584: \邨
  E586: \斵
  E58A: \効
  E58C: \躭
  E58E: \冲
  E595: \鑛
  E59C: \蔴
  E59E: \烟
  E59F: \粧
  E5A2: \叁
  E5A6: \廻
  E5A7: \凟
  E5CC: \煊
  E5CE: \詧
  E5CF: \峯
  E5D0: \叁
  E5D5: \湶
  E5D8: \％
  E5D9: \～
  E5DD: \圝
  E5E0: \焇
  E5EE: \熺
  E5EF: \烱
  E5F0: \焿
  E5FD: \魩
  E8DF: \敍
  E8E0: \斲
  E8E2: \堃
  E8E4: \崐
  E8E5: \羣
  E8E8: \凃
  E8F1: \鼈
  E8F7: \㯣

/* item header spec:

E622 -> 一、 ~ E685 一○○、
E686 -> (一) ~ E6E9 (一○○)
E6EA -> 1. ~ E74D 100.
E74E -> (1) ~ E7B1 (100)
E7B2 -> （1） circle ~ E815 （100） circle
E816 -> （一） ~ E879 （一○○）
E87A -> 0 ~ E8DE 100
*/

zhnumber = <[○ 一 二 三 四 五 六 七 八 九 十]>

zhprecision2 = ['', \十]

parseZhNumberUnit2 = (idx, value) ->
  precision = zhprecision2[idx]
  number = if value == '一' and idx !~= 0 or value == '○' and idx ~= 0 then '' else value

  '' + number + precision

parseZhNumber3 = ->
  if it .length == 3 then return it .join ''
  if it .length == 1 and it[0] == '○' then return it .join ''

  [parseZhNumberUnit2 k, v for k, v of it .reverse!] .reverse! .join ''

numToZhNumber = ->
  parseZhNumber3 (it .toString! .split '' .map -> zhnumber[it])

export umap = {[parseInt(k,16) , v] for k, v of charmap} <<< \
  {[0xE6EA + n - 1 , "#n."] for n in [1 to 100]} <<< \
  {[0xE74E + n - 1 , "(#{n})"] for n in [1 to 100]} <<< \
  {[0xE7B2 + n - 1 , "（#{n}）"] for n in [1 to 100]} <<< \
  {[0xE87A + n , "#n"] for n in [0 to 100]} <<< \
  {[0xE622 + n - 1, (numToZhNumber n) + '、'] for n in [1 to 100]} <<<  \
  {[0xE686 + n - 1, '(' + (numToZhNumber n) + ')'] for n in [1 to 100]} <<< \
  {[0xE816 + n - 1, '（' + (numToZhNumber n) + '）'] for n in [1 to 100]}

export function buildmap(cmap = umap)
  regex = [k for k of cmap].map(-> String.fromCharCode it).join \|
  [new RegExp("(#regex)", 'g'), -> cmap[it.charCodeAt 0]]

export function applymap(str)
  [pattern, replace] = buildmap!
  str.replace pattern, (_, _1) -> replace _1


