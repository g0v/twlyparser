twlyparser
============

WARNING: this is work in progress and the file format is likely to change

install unoconv

```
npm i
mkdir meta
sh ./list 4004 > meta/4004.html
./node_modules/.bin/lsc ./parse-list.ls --id 4004 --file meta/4004.html
/Applications/LibreOffice.app/Contents/MacOS/python ~/git/sysadmin/unoconv/unoconv  -f html output-4004-01-2-*.doc
./node_modules/.bin/lsc ./parse-log.ls output-4004-01-2-*.html > 4004.json
```

# CC0 1.0 Universal

To the extent possible under law, Chia-liang Kao has waived all copyright
and related or neighboring rights to twlyparser.

This work is published from Taiwan.

http://creativecommons.org/publicdomain/zero/1.0
