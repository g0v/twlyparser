require! \./ly
require! request

# Get array of static links that refer to communique files.
# specify id, year, vol... to build a URL of a web page, then parse the content.
# then we got links such as
#
#     http://lci.ly.gov.tw/LyLCEW/communique/work/89/50/LCIDC01_895001_00001.doc
#
export function getFileList({year, vol, book, seq}, id, type, cb)
  err, res, body <- request do
    method: 'POST'
    uri: 'http://lci.ly.gov.tw/LyLCEW/dwr/call/plaincall/Lci2tCommFileAttachDWR.query.dwr'
    headers:
      Origin: 'http://lci.ly.gov.tw'
      Referer: 'http://lci.ly.gov.tw/LyLCEW/lcivCommMore.action'
      User-Agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.17 (KHTML, like Gecko) Chrome/24.0.1312.5 Safari/537.17'
    form:
      callCount: 1
      windowName: ''
      'c0-scriptName': 'Lci2tCommFileAttachDWR'
      'c0-methodName': 'query'
      'c0-id': '0'
      'c0-param0': "string:#{year}"
      'c0-param1': "string:#{vol}"
      'c0-param2': "string:#{book}"
      'c0-param3': "string:#{seq}"
      'c0-param4': 'null:null'
      'c0-param5': 'string:' + if type is \html => 4 else 2
      'c0-param6': 'null:null'
      batchId: 3
      instanceId: 0
      page: '/LyLCEW/lcivCommMore.action'
      scriptSessionId: 'G2QK8XSngQBcD1FnDRSQj3XmZHj/VlFd*Hj-A9LrEZ7og'
  [_, entry] = body.match /r.handleCallback\((.*)\);/
  [_, _, entry]? = try eval "[#{entry}]" # XXX: sandbox
  cb entry.map ({filePath}) ->
    uri = switch type
    | \html => 'http://lci.ly.gov.tw/LyLCEW/jsp/ldad000.jsp?irKey=&htmlType=communique&fileName='
    else 'http://lci.ly.gov.tw/LyLCEW/'
    uri + filePath.replace /\\/g, '/'

