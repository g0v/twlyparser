require! {xregexp, path}
require! \js-yaml

class Rules

    (fname) -> 
        @_cache = {}
        @patterns = require path.resolve fname
        throw "yaml is empty" unless @patterns

    rule: (query) ->
        [groupname, rulename] = query.split \.
        if groupname is void or rulename is void
            throw "invalide rule: #query"

        try
            @patterns[groupname][rulename]
        catch e
            throw "rule not found #query #e"

    regex: (query, flag) ->
        if flag
            regexname = "#query~#flag"
        else
            regexname = query
        flag ?= ''
        if not @_cache[regexname]
            regexstr = @rule query .regex
            throw "query does not have regex string" if regexstr is void
#            @_cache[query] = new xregexp.XRegExp.cache regexstr.replace "\n", ''
            @_cache[regexname] = new RegExp (regexstr.replace "\n", ''), flag
        @_cache[regexname]

    replace: (query, _from, to_) ->
        @regex query .replace _from _to

    match: (query, text, flag) ->
        regex = @regex query, flag
        text.match regex

module.exports = {Rules}

# test code
#rules = new Rules \patterns.yml
#console.log rules.match \header.chairman, "主　　席　王院長金平"
