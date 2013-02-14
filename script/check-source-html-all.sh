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
  n_doc=`ls source/${j}/*.doc|wc|awk '{print $1}'`
  n_html=`ls source/${j}/*.html|wc|awk '{print $1}'`
  if [ "${n_doc}" == "${n_html}" ]
  then
    continue
  fi
  echo "${j}: n_doc: ${n_doc} n_html: ${n_html}"
done

cd ${current_dir}
