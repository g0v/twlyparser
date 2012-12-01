require!  {index: \../data/index,gazettes: \../data/gazettes}

function forGazette (gazette, cb)
    for id, g of gazettes when !gazette? || id ~= gazette => let id, g
        entries = [i for i in index when i.gazette ~= id]
        bytype = {}
        for {type}:i in entries
            (bytype[type] ||= []).push i
        for type, entries of bytype
            allfiles = [uri for uri of {[x,true] \
                for x in entries.map(-> it.files ? []).reduce (+++)}]
            cb id, g, type, entries, allfiles

module.exports = { forGazette, index, gazettes }
