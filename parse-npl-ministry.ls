#!/usr/bin/env lsc
# usage:
# curl -X POST -d 'startYear=102&startMonth=1&startDay=1&endYear=102&endMonth=12&endDay=1&pagingSize=100' http://npl.ly.gov.tw/do/www/ministryReportList > /tmp/zzz.html
# lsc parse-npl-ministry.ls zzz.html

# XXX pagingSize is limited to 100, need to handling paging
require! <[fs cheerio optimist sprintf]>
files = optimist.argv._




console.log <[date sitting speaker summary link]>.join \,
require! \./lib/rules
require! \./lib/util
rules = new rules.Rules \patterns.yml

export function _calendar_session({ad,session,extra})
  return unless ad and session
  _session = if extra
    sprintf "%02dT%02d", session, extra
  else
    sprintf "%02d", session
  sprintf "%02d-%s", ad, _session


export function _sitting_id({committee,sitting}:entry)
  session = _calendar_session entry
  return unless session and sitting
  sitting_type = if committee => committee.join '-' else 'YS'
  [session, sitting_type, sprintf "%02d" sitting].join \-

parse-sitting = ->
  if it is /公聽會/
    return it
  if it is /院會/
    return it
  if it.match rules.regex \header.title_committee
    res =
      ad: +that.1
      session: +that.2
      sitting: +that.4
      committee: util.parseCommittee that.3
    return _sitting_id res
  else
    throw it

files.forEach (file) ->
  $ = cheerio.load (fs.readFileSync file, \utf8)#.toLowerCase!

  allkeys = {}

  trim = -> it - /^\s+|\s+$/g - /\r\n\s+/g

  var date
  var sitting
  var type
  var speaker
  $ 'form table' .each -> if it >= 4
    res = @find "tr" .map ->
      @find \td .map -> trim @text!
    [_, date]? = res.shift!0?split '. '
    return unless date
    [y, m, d] =date.split \/
    return unless y
    res = {[k,v] for [k,v] in res}
    a = @find \a
    if a.length
      res.link = 'http://npl.ly.gov.tw' + a.attr \href
    sitting = parse-sitting res.會議別
    console.log [date, sitting, res.報告單位, res.報告名稱, res.link].join \,
