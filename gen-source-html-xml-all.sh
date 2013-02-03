#!/bin/bash

start=3109
end=4027

for ((j = ${end}; j >= ${start}; j--))
do
  echo "${j}"
  mkdir -p source-html/${j}
  mkdir -p source-xml/${j}
  for k in `ls source-pdf/${j}/*.pdf`
  do
    filename_html=`echo "${k}"|sed 's/pdf/html/g'`
    echo "pdftohtml -c -hidden ${k} ${filename_html}"
    pdftohtml -c -hidden ${k} ${filename_html}
    filename_xml=`echo "${k}"|sed 's/pdf/xml/g'`
    echo "pdftohtml -c -hidden -xml ${k} ${filename_xml}"
    pdftohtml -c -hidden -xml ${k} ${filename_xml}
  done
done
