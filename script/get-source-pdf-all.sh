#!/bin/bash

current_dir=`pwd`
base_current_dir=`echo "${current_dir}"|sed '/s.*\//g'`
if [ "${base_current_dir}" == "script" ]
  source set_dir.sh
else
  source script/set_dir.sh
fi

source set_range.sh

LSC="${twlyparser_dir}/node_modules/.bin/lsc"

cd ${twlyparser_dir}
for ((j = ${end}; j >= ${start}; j--))
do
  echo "${j}"
  ${LSC} get-source-pdf.ls --gazette ${j}
done
