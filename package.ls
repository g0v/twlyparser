#!/usr/bin/env lsc -cj
autho:
  name: ['Chia-liang Kao']
  email: 'clkao@clkao.org'
name: 'twlyparser'
description: 'Parse TW Congress log'
version: '0.0.3'
repository:
  type: 'git'
  url: 'git://github.com/g0v/twlyparser.git'
scripts:
  prepublish: """
    ./node_modules/.bin/lsc -cj package.ls &&
    ./node_modules/.bin/lsc -cb -o lib src
  """
  postinstall: """
    ./node_modules/.bin/lsc -cj package.ls &&
    ./node_modules/.bin/lsc -cb -o lib src
  """
main: 'lib/ly.js'
engines:
  node: '0.8.x'
  npm: '1.1.x'
dependencies: {}
devDependencies:
  LiveScript: ">= 1.1.1"
  optimist: \0.3.x
  cheerio: \0.10.x
  request: \2.12.x
  q: \0.8.7
  mkdirp: \0.3.x
  marked: \0.2.6
  shelljs: \0.1.x
  execSync: \0.0.x
  xregexp: \2.0.0
  async: \0.1.x
  printf: \0.0.7
  'js-yaml': \1.0.3
optionalDependencies: {}
