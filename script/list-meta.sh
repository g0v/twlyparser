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
  echo "list-meta: ${j}"
  sh ./list ${j} > source/meta/${j}.html
done

cd ${current_dir}
