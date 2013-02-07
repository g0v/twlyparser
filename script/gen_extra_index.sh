#!/bin/bash

current_dir=`pwd`
base_current_dir=`echo "${current_dir}"|sed '/s.*\//g'`
if [ "${base_current_dir}" == "script" ]
then
  cd ..
fi

echo "php script/gen_extra_index.php data/extra/extra_files.txt > data/extra/index.extra.json"
php script/gen_extra_index.php data/extra/extra_files.txt > data/extra/index.extra.json

cd "${current_dir}"
