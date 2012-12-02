/* extract resource data from markdown to json */
require! {path, fs, optimist}
require! \./lib/util
{Parser, ResourceParser} = require \./lib/parser

{dir = '.' } = optimist.argv

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

fs.readdir dir, gen_interp_json
