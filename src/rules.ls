require! {xregexp, path}
require! \js-yaml

class Rules

    (fname) -> 
        @patterns = require path.resolve fname

    rule: (query) ->
        [groupname, rulename] = query.split \.
        if groupname is undefined or rulename is undefined 
            throw "invalide rule: #query"

        try
            @patterns[groupname][rulename]
        catch e
            throw "rule not found #query"

    regex: (query) ->
        regexstr = @rule query .regex
        throw "query does not regex string" if regexstr is undefined
        new xregexp.XRegExp regexstr.replace "\n", ''

    replace: (query, _from, to_) ->
        @regex query .replace _from _to

    match: (query, text) ->
        regex = @regex query
        regex.xexec text

# test code
#rules = new Rules \patterns.yml
#console.log rules.match \header.chairman, "主　　席　王院長金平"
