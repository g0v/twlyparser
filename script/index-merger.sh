#!/bin/bash

current_dir=`pwd`
base_current_dir=`echo "${current_dir}"|sed '/s.*\//g'`
if [ "${base_current_dir}" == "script" ]
then
  cd ..
fi

./node_modules/.bin/lsc -d index-merger.ls data/index.json data/extra/index.extra.json > data/extra/index.merge.json
cp data/extra/index.merge.json data/index.json

cd ${current_dir}
