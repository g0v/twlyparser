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
  mkdir -p source-html/${j}
  mkdir -p source-xml/${j}
  for k in `ls source/pdf/${j}/*.pdf`
  do
    filename_html=`echo "${k}"|sed 's/pdf/html/g'|sed 's/source/source\/pdf/g'`
    echo "pdftohtml -c -hidden ${k} ${filename_html}"
    pdftohtml -c -hidden ${k} ${filename_html}
    filename_xml=`echo "${k}"|sed 's/pdf/xml/g'|sed 's/source/source\/pdf/g'`
    echo "pdftohtml -c -hidden -xml ${k} ${filename_xml}"
    pdftohtml -c -hidden -xml ${k} ${filename_xml}
  done
done

cd ${current_dir}