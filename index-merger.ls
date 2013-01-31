require! {optimist, fs, path}
require! \./lib/util

HashToList = (the_hash) -> 
  result = []
  for key, val of the_hash
    result.push val
  result

FoldFiles = (json_st_from, json_st_to) -> 
  put_files = {}
  for each_file in json_st_to.files
    put_files[each_file] = true

  for each_file in json_st_from.files
    if put_files[each_file]?
      continue
    put_files[each_file] = true
    json_st_to.files.push each_file

Repeat = (str, length) ->
  new Array length .join str

PadZeroLeft = (num, length) ->
  zeros = Repeat('0', length);
  num_with_zero = zeros + '' + num
  strlen = num_with_zero.length
  result = num_with_zero .substr strlen - length

JsonListToHash = (json_list) ->
  hash_st = {}
  for json_st in json_list
    gazette = json_st.gazette
    book = json_st.book
    seq = PadZeroLeft(json_st.seq, 2)
    key = gazette + '-' + book + '-' + seq
    
    if hash_st[key]? 
      FoldFiles json_st, hash_st[key]
    else 
      hash_st[key] = json_st
  hash_st

GetJsonList = (filename_list) ->
  result = []
  for filename in filename_list
    the_json = util.readFileSync filename
    the_json_st = JSON.parse the_json
    for each_json_st in the_json_st
      result.push each_json_st
  result

SortObjectByKey = (the_object) ->
  keys = Object.keys the_object
  keys.sort
  result = {}
  for i in keys
    result[i] = the_object[i]
  result

json_st_list = GetJsonList optimist.argv._
json_st_hash = JsonListToHash json_st_list
sort_json_st_hash = SortObjectByKey json_st_hash
result = HashToList json_st_hash
console.log JSON.stringify result, null, 4
