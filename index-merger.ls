require! {optimist, fs, path, printf}
require! \./lib/util
require! \./lib/util_hsiao

foldFilesToPutFiles = (json_st_from, json_st_to) ->
  put_files = [{each_file: true} for each_file in json_st_to.files]

  result = []
  for each_file in json_st_from.files
    if put_files[each_file]? then continue
    put_files[each_file] = true
    result.push each_file
  result
  
foldFiles = (json_st_from, json_st_to) -> 
  to_put_files = foldFilesToPutFiles json_st_from, json_st_to
  json_st_to.files ++ to_put_files

convertListToHash = (json_list) ->
  hash_st = {}
  for json_st in json_list
    key = printf "%05d%02d%02d", json_st.gazette, json_st.book, json_st.seq
    if hash_st[key]? then foldFiles json_st, hash_st[key] else hash_st[key] = json_st
  hash_st

getJsonStFromFilename = (filename) -> 
  the_json = util.readFileSync filename
  the_json_st = JSON.parse the_json

getJsonStList = (filename_list) ->
  result = [getJsonStFromFilename(each_file) for each_file in filename_list] |> concat

sortObjectByKey = (the_object) ->
  keys = Object.keys the_object ..sort!
  result = [the_object[i] for i in keys]

json_st_list = getJsonStList optimist.argv._
json_st_hash = convertListToHash json_st_list
sort_json_st_hash = sortObjectByKey json_st_hash
result = util_hsiao.hashToList sort_json_st_hash
result_json = JSON.stringify result, null, 4
console.log result_json
