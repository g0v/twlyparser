require! {fs, async, path, mkdirp, request}

fixupHtml = ->
    it  .replace /&\#28216;&\#31192;&\#26360;&\#38263;&\#37675;&\#12289;/g, '游秘書長錫堃、'
        .replace /&\#28216;&\#22519;&\#34892;&\#38263;&\#37675;&\#12289;/g, '游執行長錫堃、'
        .replace /&\#28216;&\#31192;&\#26360;&\#38263;&\#37675;&\#26280;/g, '游秘書長錫堃暨'
        .replace /&\#28216;&\#31192;&\#26360;&\#38263;&\#37675;&\#29575;/g, '游秘書長錫堃率'
        .replace /&\#37675;&\#65533;/g, '錫堃'
        .replace /&\#57789;/g, '%'
        .replace /&\#58455;/g, '堦'
        .replace /&\#58738;/g, '粧'
        .replace /&\#58753;/g, '銹'
        .replace /&\#58766;/g, '冲'
        .replace /&\#58828;/g, '煊'
        .replace /&\#58831;/g, '峯'
        .replace /&\#59014;/g, '(二)'
        .replace /&\#59015;/g, '(三)'
        .replace /&\#59016;/g, '(四)'
        .replace /&\#59615;/g, '敘'
        .replace /&\#59618;/g, '堃'
        .replace /&\#59620;/g, '崐'
        .replace /&\#65335;&\#65332;&\#9675;/g, '&#65335;&#65332;&#65327;' #WTO
        .replace /&\#63512;/g, '粧'
        .replace /&\#65533;&\#26412;&\#38498;&\#22996;&\#21729;&\#40643;&\#26157;&\#38918;/g, '(一)本院委員黃昭順'
        .replace /&\#65533;&\#26412;&\#38498;&\#22996;&\#21729;&\#26519;&\#24503;&\#31119;/g, '(二)本院委員林德福'
        .replace /&\#65533;&\#26412;&\#38498;&\#22996;&\#21729;&\#21608;&\#37675;&\#29771;/g, '(三)本院委員周錫瑋'
        .replace /&\#65533;&\#26412;&\#38498;&\#22996;&\#21729;&\#29579;&\#24184;&\#30007;/g, '(四)本院委員王幸男'
        .replace /&\#65533;&\#26412;&\#38498;&\#22996;&\#21729;&\#26446;&\#25991;&\#24544;/g, '(五)本院委員李文忠'
        .replace /&\#65533;&\#34892;&\#25919;&\#38498;/g, '(六)行政院'
        .replace /&\#65533;&\#26412;&\#38498;&\#21488;&\#32879;&\#40680;&\#22296;&\#25836;&\#20855;&\#20043;&\#12300;&\#22283;&\#23478;&\#24773;&\#27835;/g, '(七)本院台聯黨團擬具之「國家情治'
        .replace /&\#65533;&\#26412;&\#38498;&\#21488;&\#32879;&\#40680;&\#22296;&\#25836;&\#20855;&\#20043;&\#12300;&\#22283;&\#23478;&\#24773;&\#22577;/g, '(八)本院台聯黨團擬具之「國家情報'
        .replace /&\#65533;&\#26412;&\#38498;&\#35242;&\#27665;&\#40680;&\#40680;&\#22296;&\#25836;&\#20855;&\#20043;&\#12300;&\#24773;&\#22577;&\#30435;&\#30563;/g, '(九)本院親民黨黨團擬具之「情報監督'
        .replace /&\#65533;&\#26412;&\#38498;&\#22283;&\#27665;&\#40680;&\#40680;&\#22296;&\#25836;&\#20855;&\#20043;&\#12300;&\#22283;&\#23478;&\#24773;&\#22577;/g, '(十)本院國民黨黨團擬具之「國家情報'
        .replace /&\#65533;/g, '粧'


readHtmlFileSync = (path) -> fixupHtml fs.readFileSync path, \utf8

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
  result = {[val, true] for val in the_list}

nonRepeatedList = (the_list) ->
  the_list_to_hash = listToHash the_list
  the_hash_to_list = hashKeyToList the_list_to_hash

debug = (info, filename, function_name, prompt, val) ->
  console.log '[' + info + ']', filename + ':', function_name + ':', prompt + ':'
  console.log val
  console.log typeof val

module.exports = {getUriList, nonRepeatedList, debug, hashToList, hashKeyToList, listToHash, readHtmlFileSync}