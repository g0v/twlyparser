#!/bin/bash

if [ "${BASH_ARGC}" == 1 ]
  then
  data_dir=${BASH_ARGV[0]}
else
  data_dir=output
fi

current_dir=`pwd`
base_current_dir=`echo "${current_dir}"|sed '/s.*\//g'`
if [ "${base_current_dir}" == "script" ]
then
  cd ..
fi

source script/set_range.sh

#for ((j = ${end}; j >= ${start}; j--))
for ((j = 4027; j >= ${start}; j--))
do
  echo "committee: ${j}"
  ./node_modules/.bin/lsc format-committee-log.ls --gazette ${j} --dir ${data_dir} --text
done

cd ${current_dir}
