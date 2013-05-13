#!/usr/bin/env lsc
# use the chrome extension to download full html from tts-based ly site
# https://chrome.google.com/webstore/detail/%E7%AB%8B%E6%B3%95%E9%99%A2%E6%93%B4%E5%85%85/ingofalhkimajgdgaplblnkhpenjhmpo?hl=en
# iconv -f big5-2003 -t utf8
# and parse with this
require! <[fs cheerio optimist]>
{bill} = optimist.argv
[file] = optimist.argv._

$ = cheerio.load (fs.readFileSync file, \utf8).toLowerCase!

allkeys = {}

trim = -> it - /^\s+|\s+$/g

tables = $ 'blockquote table[width="90%"]' .map ->
    all = @find \tr .map ->
        [k, v] = @find \td .map -> @
        k .= text!
        a = v.find \a
        v = if a.length
            a.each ->
                match @attr \href - // ^http:\/\/lis.ly.gov.tw //
                | // /ttscgi/ttsweb // => @replaceWith @text! # internal link
                | // /lgcgi/ttsweb //  => @replaceWith @text! # internal link
                | // /lgcgi/ttspage3\?\d+@\d+@\d+@(\d\d)(\d\d)(\d\d)(\d\d):([\d\-]+)@ // =>
                    @replaceWith @text! + ' ' + JSON.stringify <[a]> ++ +that[1 to 4] ++ that.5
                | // /lgcgi/lypdftxt\?(\d\d\d?)(\d\d\d)(\d\d);(\d+);(\d+) // =>
                    @replaceWith @text! + ' ' + JSON.stringify <[g]> ++ +that[1 to 5]
                | // /ttscgi/lgimg\?@(\d\d)(\d\d\d)(\d\d);(\d+);(\d+) // =>
                    @replaceWith @text! + ' ' + JSON.stringify <[gi]> ++ +that[1 to 5]
                | // /lgcgi/lgmeetimage\?(.*) // =>
                    @replaceWith @text! + ' ' + JSON.stringify <[gm]> ++ that.1

            if !bill and k is /發言委員|法名稱|答復公報/
                v.html!split '<br>' .filter (.length) .map trim
            else
                v.html!
        else
            v.text!
        if bill
            if k is '審議進度'
                return
            if k is '提案委員/機關'
                sponsor = {}
                v.split /\n/ .forEach ->
                  [_, who, how]? = it.match /\s*(.*?)\s*\((.*?)\)\s*/
                  return unless who
                  sponsor[how] ?= []
                    ..push who
                return [k, sponsor]

        if k is /^(委員會|類別|主題|關鍵詞|質詢人|答復人|答復日期|提案機關|機關|案別|附加詞|主席)$/ or (!bill and k is /^提案編號|法編號$/)
            v = v.split /;/ .map trim
        v = trim v if typeof! v isnt \Array
        allkeys[k] ?= 0
        allkeys[k]++
        [k, v]
    {[k,v] for [k, v]? in all when k}

console.log JSON.stringify tables, null, 4

