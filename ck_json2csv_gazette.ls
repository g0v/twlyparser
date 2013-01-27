require! {fs, optimist}

x = require \./data/gazettes.json

for serial, time of x
    console.log "#serial,#{(time.date / ':')[0]}"
