#!/bin/bash

start=3109
end=4027
LSC="./node_modules/.bin/lsc"

for ((j = ${end}; j >= ${start}; j--))
do
  echo "${j}"
  ${LSC} get-source-pdf.ls --gazette ${j}
done
