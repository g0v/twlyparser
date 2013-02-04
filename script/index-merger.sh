#!/bin/bash

current_dir=`pwd`
base_current_dir=`echo "${current_dir}"|sed '/s.*\//g'`
if [ "${base_current_dir}" == "script" ]
  source set_dir.sh
else
  source script/set_dir.sh
fi

./node_modules/.bin/lsc -d index-merger.ls data/index.json data/extra/index.extra.json > data/index.merge.json
mv data/index.merge.json data/index.json
