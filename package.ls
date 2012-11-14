author:
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
    ./node_modules/.bin/lsc -cj package.ls
  """
engines:
  node: '0.8.x'
  npm: '1.1.x'
dependencies: {}
devDependencies:
  LiveScript: \1.1.x
  optimist: \0.3.x
  cheerio: \0.10.x
  request: \2.12.x
optionalDependencies: {}
