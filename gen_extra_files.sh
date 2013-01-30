#!/bin/bash

PYTHON="/Applications/LibreOffice.app/Contents/MacOS/python"

SRC_PREFIX="source/extra"
DATA_PREFIX="data/extra"

mkdir -p ${SRC_PREFIX}
for j in `cat ${DATA_PREFIX}/extra_docs.txt`
do
  echo ${j}
  filename=`echo "${j}"|sed 's/.*\///g'`
  filename="${SRC_PREFIX}/${filename}"
  echo "${j} -> ${filename}"
  curl "${j}" > ${filename} 
done

echo "${PYTHON} unoconv/unoconv -f html ${SRC_PREFIX}/*.doc"
${PYTHON} unoconv/unoconv -f html ${SRC_PREFIX}/*.doc

ls ${SRC_PREFIX}/*.html > ${DATA_PREFIX}/extra_files.txt

