/* extract resource data from markdown to json */
require! {path, fs, optimist}
require! \./lib/util
{Parser, ResourceParser} = require \./lib/parser

{dir = '.' } = optimist.argv


relations_map_fname = "#dir/index_people_interp.json"

if not fs.exists relations_map_fname
    console.log "create"
    relations_map = {}
else
    relations_map = JSON.parse util.readFileSync relations_map_fname

save_map = (relations_map) ->
    fs.writeFileSync relations_map_fname, JSON.stringify relations_map, null , 4b

gen_interp_json = (err, files) -> 
                    if err
                        console.log err
                    else
                        for fname in files
                            ext = path.extname fname
                            continue unless ext is'.md'

                            console.log fname
                            id = fname.replace('.md', '')
                            dest_fname = "#dir#id" +"_interp.json"
                            console.log dest_fname
                            
                            output = fs.openSync dest_fname, \w

                            parser = new ResourceParser output: (...args) -> fs.writeSync output, (args)
                            parser.parseMarkdown util.readFileSync "#dir/#fname"
                            parser.store!
                            fs.closeSync output
                            util.build_people_interp_map id, parser.results, relations_map
                            save_map relations_map
        
fs.readdir dir, gen_interp_json

