require! {xregexp, path}
require! \js-yaml

class Rules

    (fname) -> 
        @_cache = {}
        @patterns = require path.resolve fname
        throw "yaml is empty" unless @patterns

    rule: (query) ->
        [groupname, rulename] = query.split \.
        if groupname is undefined or rulename is undefined 
            throw "invalide rule: #query"

        try
            @patterns[groupname][rulename]
        catch e
            throw "rule not found #query #e"

    regex: (query) ->
        if not @_cache[query]
            regexstr = @rule query .regex
            throw "query does not have regex string" if regexstr is undefined
            @_cache[query] = new xregexp.XRegExp.cache regexstr.replace "\n", ''
        @_cache[query]

    replace: (query, _from, to_) ->
        @regex query .replace _from _to

    match: (query, text) ->
        @regex query .exec text

module.exports = {Rules}

# test code
#rules = new Rules \patterns.yml
#console.log rules.match \header.chairman, "主　　席　王院長金平"
