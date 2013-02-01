#!/bin/bash

if [ ! -f data/index.json.orig.for_merge ]
  then
  cp data/index.json data/index.json.orig.for_merge
fi
./node_modules/.bin/lsc -d index-merger.ls data/index.json data/index.extra.json > data/index.merge.json
mv data/index.merge.json data/index.json
