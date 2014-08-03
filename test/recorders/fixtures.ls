require! <[path]>
require! \../../lib/ly
YAML = require \yamljs

export files_of = (dir) ->
  funcs = {
    calendar: files_of_calendar
  }
  funcs[dir]!

files_of_calendar = ->
  files = [
    ['2014', '63421'],
    ['2014', '60881']
  ]
  files.map ->
    {year: it[0], seen: it[1]}

export shot_snapshots_of = (dir, file, cb) ->
  funcs = {
    calendar: shot_snapshots_of_calender
  }
  snapshots <- funcs[dir] file
  cb snapshots

shot_snapshots_of_calender = (file, cb) ->
  snapshots <- ly.get-calendar-by-year file.year, file.seen
  cb snapshots

export load_cassettes = (dir, file) ->
  YAML.load cassettes_of dir, file

export load_snapshots = (dir, file) ->
  YAML.load snapshots_of dir, file

export cassettes_of = (dir, file) ->
  filename = name_of_file file
  path_of_cassettes_of dir, "#filename.yml"

export snapshots_of = (dir, file) ->
  filename = name_of_file file
  path_of_snapshots_of dir, "#filename.yml"

name_of_file = (file) ->
  JSON.stringify file
  .replace /^{/, '['
  .replace /}$/, ']'

path_of_cassettes_of = (dir, filename) ->
  path.join path_of_cassettes!, dir, filename

path_of_snapshots_of = (dir, filename) ->
  path.join path_of_snapshots!, dir, filename

path_of_cassettes = ->
  path.join base!, dir_of_cassettes!

path_of_snapshots = ->
  path.join base!, dir_of_snapshots!

export base = ->
  path.join cwd!, '/test/fixtures'

export cwd = ->
  process.cwd!

dir_of_cassettes = -> 'cassettes'

dir_of_snapshots = -> 'snapshots'
