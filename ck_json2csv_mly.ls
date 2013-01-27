require! {fs, optimist}

x = require \./data/mly-8.json

for {name, party} in x => console.log "#name,#party"
