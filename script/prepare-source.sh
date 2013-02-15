#!/bin/bash

current_dir=`pwd`
base_current_dir=`echo "${current_dir}"|sed '/s.*\//g'`
if [ "${base_current_dir}" == "script" ]
then
  cd ..
fi

source script/set_range.sh

cp data/index.json data/index.json.orig
for ((j = ${end}; j >= ${start}; j--))
do
  echo "prepare-source: ${j}"
  ./node_modules/.bin/lsc ./prepare-source.ls --gazette ${j}
  cp data/index-files.json data/index.json
done
cp data/index.json data/index-files.json
mv data/index.json.orig data/index.json

cd ${current_dir}
