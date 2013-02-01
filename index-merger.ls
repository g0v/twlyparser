require! {optimist, fs, path, printf}
require! \./lib/util

hash-to-list = (the_hash) -> 
  result = [val for key, val of the_hash]

fold-files-to-put-files = (json_st_from, json_st_to) ->
  put_files = [{each_file: true} for each_file in json_st_to.files]
  result = []
  for each_file in json_st_from.files
    if put_files[each_file]? then continue
    put_files[each_file] = true
    result.push each_file
  
fold-files = (json_st_from, json_st_to) -> 
  to_put_files = fold-files-to-put-files json_st_from, json_st_to
  json_st_to.files.concat to_put_files

json-list-to-hash = (json_list) ->
  hash_st = {}
  for json_st in json_list
    key = printf "%05d%02d%02d", json_st.gazette, json_st.book, json_st.seq
    if hash_st[key]? then fold-files json_st, hash_st[key] else hash_st[key] = json_st
  hash_st

get-json-st-from-filename = (filename) -> 
  the_json = util.read-file-sync filename
  the_json_st = JSON.parse the_json

get-json-list = (filename_list) ->
  result = [get-json-st-from-filename(each_file) for each_file in filename_list] |> concat

sort-object-by-key = (the_object) ->
  keys = Object.keys the_object
  keys.sort!
  result = [the_object[i] for i in keys]

json_st_list = get-json-list optimist.argv._
json_st_hash = json-list-to-hash json_st_list
sort_json_st_hash = sort-object-by-key json_st_hash
result = hash-to-list sort_json_st_hash
result_json = JSON.stringify result, null, 4
console.log result_json
