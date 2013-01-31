if (typeof window == 'undefined' || window === null) {
  require('prelude-ls').installPrelude(global);
} else {
  prelude.installPrelude(window);
}
(function(){
  var optimist, fs, path, printf, util, HashToList, FoldFiles, JsonListToHash, GetJsonList, SortObjectByKey, json_st_list, json_st_hash, sort_json_st_hash, result, result_json;
  optimist = require('optimist');
  fs = require('fs');
  path = require('path');
  printf = require('printf');
  util = require('./lib/util');
  HashToList = function(the_hash){
    var result, key, val;
    return result = (function(){
      var ref$, results$ = [];
      for (key in ref$ = the_hash) {
        val = ref$[key];
        results$.push(val);
      }
      return results$;
    }());
  };
  FoldFiles = function(json_st_from, json_st_to){
    var put_files, i$, ref$, len$, each_file, results$ = [];
    put_files = {};
    for (i$ = 0, len$ = (ref$ = json_st_to.files).length; i$ < len$; ++i$) {
      each_file = ref$[i$];
      put_files[each_file] = true;
    }
    for (i$ = 0, len$ = (ref$ = json_st_from.files).length; i$ < len$; ++i$) {
      each_file = ref$[i$];
      if (put_files[each_file] != null) {
        continue;
      }
      put_files[each_file] = true;
      results$.push(json_st_to.files.push(each_file));
    }
    return results$;
  };
  JsonListToHash = function(json_list){
    var hash_st, i$, len$, json_st, key;
    hash_st = {};
    for (i$ = 0, len$ = json_list.length; i$ < len$; ++i$) {
      json_st = json_list[i$];
      key = printf("%05d%02d%02d", json_st.gazette, json_st.book, json_st.seq);
      if (hash_st[key] != null) {
        FoldFiles(json_st, hash_st[key]);
      } else {
        hash_st[key] = json_st;
      }
    }
    return hash_st;
  };
  GetJsonList = function(filename_list){
    var result, i$, len$, filename, the_json, the_json_st, j$, len1$, each_json_st;
    result = [];
    for (i$ = 0, len$ = filename_list.length; i$ < len$; ++i$) {
      filename = filename_list[i$];
      the_json = util.readFileSync(filename);
      the_json_st = JSON.parse(the_json);
      for (j$ = 0, len1$ = the_json_st.length; j$ < len1$; ++j$) {
        each_json_st = the_json_st[j$];
        result.push(each_json_st);
      }
    }
    return result;
  };
  SortObjectByKey = function(the_object){
    var keys, result, i$, len$, i;
    keys = Object.keys(the_object);
    keys.sort();
    result = {};
    result = the_object(
    keys);
    for (i$ = 0, len$ = keys.length; i$ < len$; ++i$) {
      i = keys[i$];
      result[i] = the_object[i];
    }
    return result;
  };
  json_st_list = GetJsonList(optimist.argv._);
  json_st_hash = JsonListToHash(json_st_list);
  sort_json_st_hash = SortObjectByKey(json_st_hash);
  result = HashToList(json_st_hash);
  result_json = JSON.stringify(result, null, 4);
  console.log(result_json);
}).call(this);
