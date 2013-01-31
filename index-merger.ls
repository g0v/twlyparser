require! {optimist, fs, path, printf}
require! \./lib/util

HashToList = (the_hash) -> 
  result = [val for key, val of the_hash]

FoldFiles = (json_st_from, json_st_to) -> 
  put_files = {}
  for each_file in json_st_to.files
    put_files[each_file] = true

  for each_file in json_st_from.files
    if put_files[each_file]?
      continue
    put_files[each_file] = true
    json_st_to.files.push each_file

JsonListToHash = (json_list) ->
  hash_st = {}
  for json_st in json_list
    key = printf "%05d%02d%02d", json_st.gazette, json_st.book, json_st.seq
    
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
  keys.sort!
  result = {}
  for i in keys
    result[i] = the_object[i]
  result

json_st_list = GetJsonList optimist.argv._
json_st_hash = JsonListToHash json_st_list
sort_json_st_hash = SortObjectByKey json_st_hash
result = HashToList sort_json_st_hash
result_json = JSON.stringify result, null, 4
console.log result_json
