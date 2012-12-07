/* extract resource data from markdown to json */
require! {path, fs, optimist}
require! \./lib/util
{StructureFormater} = require \./lib/parser

{dir = '.' } = optimist.argv


gen_md = (err, files) -> 
                    if err
                        console.log err
                    else
                        for fname in files
                            ext = path.extname fname
                            continue unless ext is'.txt'

                            console.log fname
                            id = fname.replace('.txt', '')
                            dest_fname = "#dir#id.md"
                            console.log dest_fname
                            
                            output = fs.openSync dest_fname, \w

                            parser = new StructureFormater output: (...args) -> fs.writeSync output, (args)
                            parser.loadRules \patterns.yml
                            parser.parseText util.readFileSync "#dir/#fname"
                            parser.store!
                            fs.closeSync output
fs.readdir dir, gen_md

