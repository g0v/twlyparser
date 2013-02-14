#!/bin/bash

current_dir=`pwd`
base_current_dir=`echo "${current_dir}"|sed '/s.*\//g'`
if [ "${base_current_dir}" == "script" ]
then
  cd ..
fi

source script/set_range.sh

for ((j = ${end}; j >= ${start}; j--))
do
  echo "${j}"
  if [ "${j}" == 3206 ]
    then
    continue
  fi
  ./node_modules/.bin/lsc populate-sitting_hsiao.ls --dometa --gazette ${j}
done

for ((j = ${end}; j >= ${start}; j--))
do
  echo "memo: ${j}"
  ./node_modules/.bin/lsc populate-sitting_hsiao.ls --dometa --gazette ${j} --type memo
done

cd ${current_dir}
