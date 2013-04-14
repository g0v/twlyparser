#!/usr/bin/env lsc
# use the chrome extension to download full html from tts-based ly site
# https://chrome.google.com/webstore/detail/%E7%AB%8B%E6%B3%95%E9%99%A2%E6%93%B4%E5%85%85/ingofalhkimajgdgaplblnkhpenjhmpo?hl=en
# iconv -f big5-2003 -t utf8
# and parse with this
require! <[fs cheerio optimist]>
[file] = optimist.argv._

$ = cheerio.load fs.readFileSync file, \utf8

allkeys = {}

trim = -> it - /^\s+|\s+$/g

tables = $ 'blockquote table[width="90%"]' .map ->
    all = @find \tr .map ->
        [k, v] = @find \td .map -> @
        k .= text!
        a = v.find \a
        v = if a.length
            a.each ->
                match @attr \href
                | // http:\/\/lis.ly.gov.tw/ttscgi/ttsweb // => @replaceWith @text! # internal link
                | // http:\/\/lis.ly.gov.tw/lgcgi/ttsweb //  => @replaceWith @text! # internal link
                | // http:\/\/lis.ly.gov.tw/lgcgi/ttspage3\?\d+@\d+@\d+@(\d\d)(\d\d)(\d\d)(\d\d):([\d\-]+)@ // =>
                    @replaceWith @text! + ' ' + JSON.stringify <[a]> ++ that[1 to 5]
                | // http:\/\/lis.ly.gov.tw/lgcgi/lypdftxt\?(\d\d\d?)(\d\d\d)(\d\d);(\d+);(\d+) // =>
                    @replaceWith @text! + ' ' + JSON.stringify <[g]> ++ that[1 to 5]
                | // http:\/\/lis.ly.gov.tw/ttscgi/lgimg\?@(\d\d)(\d\d\d)(\d\d);(\d+);(\d+) // =>
                    @replaceWith @text! + ' ' + JSON.stringify <[gi]> ++ that[1 to 5]

            match k
            | /發言委員|法名稱/ => v.html!split '<br>' .filter (.length) .map trim
            else => v.html!
        else
            match k
            | /提案編號|委員會/ => v.text!split /;/ .map trim
            else => v.text!
        v = trim v if typeof! v isnt \Array
        allkeys[k] ?= 0
        allkeys[k]++
        [k, v]
    {[k,v] for [k, v] in all}

console.log JSON.stringify tables, null, 4

