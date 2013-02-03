require! {fs, async, path, mkdirp, request}

getUriList = (uri_list, id, prefix) -> 
  funcs = []
  funcs.push (cb) -> 
    err <- mkdirp "#{prefix}/#{id}"
    throw err if err
    cb!

  for uri in uri_list => let uri, fname = path.basename uri
    file = "#{prefix}/#{id}/#{fname}"
    funcs.push (cb) ->
      _, {size}? <- fs.stat file
      return cb! if size?
  
      console.log 'getting: ' + file + ' from: ' + uri
      writer = with fs.createWriteStream file
        ..on \error -> throw it
        ..on \close -> 
          <- setTimeout _, 1000ms
          console.log \done file
          cb!
        ..
      request {method: \GET, uri} .pipe writer

  err, res <- async.waterfall funcs
  console.log \done, 'err:' err, 'res:', res

hashKeyToList = (the_hash) -> 
  result = [key for key, val of the_hash]

hashToList = (the_hash) -> 
  result = [val for key, val of the_hash]

listToHash = (the_list) -> 
  result = {[.., true] for the_list}

nonRepeatedList = (the_list) ->
  the_list_to_hash = listToHash the_list
  the_hash_to_list = hashKeyToList the_list_to_hash

debug = (info, filename, function_name, prompt, val) ->
  console.log '[' + info + ']', filename + ':', function_name + ':', prompt + ':'
  console.log val
  console.log typeof val

module.exports = {getUriList, nonRepeatedList, debug, hashToList, hashKeyToList, listToHash}