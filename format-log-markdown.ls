/* extract resource data from markdown to json */
require! {path, fs, optimist}
require! \./lib/util
{StructureFormater} = require \./lib/parser

{inputdir = '.', outputdir = '.' } = optimist.argv
if not outputdir
    outputdir = inputdir

gen_md = (err, files) -> 
                    if err
                        console.log err
                    else
                        for fname in files
                            ext = path.extname fname
                            continue unless ext is'.txt'
                            console.log "Info: processing #fname"
                            id = fname.replace('.txt', '')
                            dest_fname = "#outputdir#id.md"
                            
                            output = fs.openSync dest_fname, \w

                            parser = new StructureFormater output: (...args) -> fs.writeSync output, (args)
                            parser.loadRules \patterns.yml
                            parser.parseText util.readFileSync "#inputdir/#fname"
                            parser.store!
                            fs.closeSync output

                            if parser.result and parser.result.endingContext is false
                                console.log "Error: #id 無正常結尾"
fs.readdir inputdir, gen_md

