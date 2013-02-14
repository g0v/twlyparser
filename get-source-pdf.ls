require! \./lib/ly
require! \./lib/util_hsiao
require! <[q optimist printf]>

{gazette} = optimist.argv

entryToUri = (year, vol, entry) ->
  http_prefix = if year >= 100 then 'http://lci.ly.gov.tw/LyLCEW/communique1/final/pdf' else 'http://lci.ly.gov.tw/LyLCEW/communique/final/pdf'
  book = printf "%02d", entry.book
  result = http_prefix + '/' + year + '/' + vol + '/LCIDC01_' + year + vol + book + '.pdf'

gazette = gazette .toString!
g = ly.gazettes[gazette];
g.entries = [each_index for each_index in ly.index when each_index.gazette == gazette];

uri_list = [entryToUri g.year, g.vol, each_entry for each_entry in g.entries]
uri_list_non_repeated = util_hsiao.nonRepeatedList uri_list
util_hsiao.getUriList uri_list_non_repeated, gazette, 'source/pdf'
