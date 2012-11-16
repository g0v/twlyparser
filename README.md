twlyparser
============

WARNING: this is work in progress and the file format is likely to change!

```
npm i
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

To parse:

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
