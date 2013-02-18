#!/bin/bash

##########
#for the source/{gazette} dirs which can not produce all htmls. specifically generate html from each doc.

if [ "${BASH_ARGC}" != 1 ]
then
  echo "usage: gen-source-html-dir.sh [gazette]"
  exit 
fi
gazette=${BASH_ARGV[0]}

current_dir=`pwd`
base_current_dir=`echo "${current_dir}"|sed '/s.*\//g'`
if [ "${base_current_dir}" == "script" ]
then
  cd ..
fi

j=${gazette}
n_doc=`ls source/${j}/*.doc|wc|awk '{print $1}'`
n_html=`ls source/${j}/*.html|wc|awk '{print $1}'`
if [ "${n_doc}" == "${n_html}" ]
then
  exit
fi

for k in `ls source/${j}/*.doc`
do
  k_html=`echo "${k}"|sed 's/doc$/html/g'`
  if [ -f "${k_html}" ]
  then
    continue
  fi
  
  echo "${k}"
  /Applications/LibreOffice.app/Contents/MacOS/python unoconv/unoconv  -f html ${k}
done

cd ${current_dir}
