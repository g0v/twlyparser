#!/bin/bash

current_dir=`pwd`
base_current_dir=`echo "${current_dir}"|sed 's/.*\//g'`
if [ "${base_current_dir}" != "script" ]
  then
  script_dir="${current_dir}/script"
else
  script_dir="${current_dir}"
fi
twlyparser_dir=`echo "${script_dir}"|sed 's/\/script//g'`
