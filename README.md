twlyparser
============

WARNING: this is work in progress and the file format is likely to change!

# Prepare environment

The files with .ls extension is a LiveScript source file. 
LiveScript is a language which compiles to JavaScript.

For emacs user, please use
https://github.com/YHisamatsu/livescript-mode for syntax highlight.

## To install node.js and npm and LiveScript in Ubunutu

The node.js in Ubuntu is pretty old and does not work with
LiveScript. Please use the one in chris ppa.

```
$ sudo add-apt-repository ppa:chris-lea/node.js
$ sudo apt-get update
$ suod apt-get install node.js npm
```

## install required node.js packages

```
~/twlyparser $ npm i

## compile 
~/twlyparser $  npm run prepublish
```

To retrieve source word files of a specific gazette that is already listed in
'data/index.json':

```
./node_modules/.bin/lsc get-source.ls --gazette 4004

```

Convert to html with 'unoconv':

```
/Applications/LibreOffice.app/Contents/MacOS/python ~/git/sysadmin/unoconv/unoconv  -f html source/4004/*.doc
```

# To parse:

twlyrawdata.tgz : download from http://dl.dropbox.com/u/30657009/ly/4004.tgz

*current*

```
twlyparser $ mkdir source/
twlyparser $ tar xzvf twlyrawdata.tgz -C source/ 
twlyparser $ ./node_modules/.bin/lsc ./format-log.ls --gazette 4004 ../twly_rawdata/*.html > data/4004.json
```

```
./node_modules/.bin/lsc ./parse-log.ls source/4004/*.html > data/4004.json
```


To bootstrap or maintain the index file cache in data/:

```
mkdir -p source/meta
sh ./list 4004 > source/meta/4004.html
./node_modules/.bin/lsc ./parse-list.ls source/meta/*.html
./node_modules/.bin/lsc ./prepare-source.ls
```

You should now have data/index-files.json.  Move to data/index.json if you are
happy with it.

# CC0 1.0 Universal

To the extent possible under law, Chia-liang Kao has waived all copyright
and related or neighboring rights to twlyparser.

This work is published from Taiwan.

http://creativecommons.org/publicdomain/zero/1.0
