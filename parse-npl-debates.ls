#!/usr/bin/env lsc
# usage:
# curl -X POST -d 'startYear=102&startMonth=1&startDay=1&endYear=102&endMonth=12&endDay=1' http://npl.ly.gov.tw/do/www/overallInter > /tmp/zzz.html
# lsc parse-npl-debates.ls zzz.html
require! <[fs cheerio optimist printf]>
files = optimist.argv._

files.forEach (file) ->
  $ = cheerio.load (fs.readFileSync file, \utf8).toLowerCase!

  allkeys = {}

  trim = -> it - /^\s+|\s+$/g

  var date
  var sitting
  var type
  var speaker
  $ 'form table[border=0]' .each -> if it is 4
    @.find "tr > td.text:first-child" .each ->
      match trim @text!
      | // (\d+)/(\d+)/(\d+)\s*立法院第(\d+)屆第(\d+)會期第(\d+)次會議 //
        [_, y,m,d, ad, session, _sitting] = that
        date := [+y + 1911, m , d].join \-
        sitting := printf "%02d-%02d-YS-%02d", ad, session, _sitting
      | // (.*?)聯合質詢$ //
        type := \debate
        speaker := that.1.split \、 .map (- /委員$/)
        speaker := speaker.join \;
      | // (.*?)委員質詢$ //
        type := \debate
        speaker := that.1
      | // (.*?報告)$ //
        type := \report
        speaker := that.1
      | /(.+)/
        a = @find \a
        if a.length
          link = a.attr \href
        console.log [date, sitting, speaker, type, that.0, link].join \,
      else
