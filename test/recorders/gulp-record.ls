require! <[through gulp-util nock buffer async colors]>
{map, maximum, find-index} = require 'prelude-ls'
require! \./fixtures
YAML = require \yamljs

{PluginError, File} = gulp-util
const PLUGIN_NAME = 'gulp-record'

module.exports = (dir) ->
  files = []
  through (file) ->
    if file.is-null! or file.is-buffer!
      files.push file
    else
      throw new PluginError PLUGIN_NAME, 'File should be null or buffer'
  , ->
    self = this
    self.pause!
    shot_fixtures dir, files, (cassettes, snapshots) ->
      self.queue cassettes
      self.queue snapshots
    , ->
      self.queue null
      self.resume!

class Paths

  (@dir, files) ->
    self = this
    self.paths = {}
    files.map ->
      self.paths[it.path] = true

  has_cassettes: (file) ->
    @paths[fixtures.cassettes_of @dir, file]

  has_snapshots: (file) ->
    @paths[fixtures.snapshots_of @dir, file]

  colorize_cassettes: (file) ->
    @colorize_path fixtures.cassettes_of @dir, file

  colorize_snapshots: (file) ->
    @colorize_path fixtures.snapshots_of @dir, file

  colorize_path: (path) ->
    @base = '' if !@base
    self = this
    [_, base_parts] = self.relative_to_cwd @base
    [_, path_parts] = self.relative_to_cwd path
    [base_parts, path_parts] = @relative_parts base_parts, path_parts
    @base = path
    @colorize_parts base_parts, path_parts

  parts_of_path: (path) ->
    parts = path.match /[^\/]+\/|[^\/]+\.yml/g
    parts =
      if parts
        parts.slice 1
      else
        []
    parts.map -> "#it "

  relative_to_cwd: (path) ->
    parts = @parts_of_path path
    cwd_parts = @parts_of_path fixtures.base!
    @relative_parts cwd_parts, parts

  relative_parts: (base_parts, path_parts) ->
    foo = @zip(path_parts, base_parts)
    i = find-index -> it[0] != it[1]
    , @zip(path_parts, base_parts)
    base_parts = base_parts.slice 0, i
    path_parts = path_parts.slice i
    [base_parts, path_parts]

  colorize_parts: (base_parts, path_parts) ->
    spaces_parts = @spaces_parts base_parts
    parts = spaces_parts.concat path_parts
    @zip(parts, @paths_color!).map (part_with_colors) ->
      [part, colors] = part_with_colors
      colors.reduce (part, current) ->
        part[current]
      , part
    .join ''

  spaces_parts: (parts) ->
    parts.map (part) ->
      Array(part.length + 1).join ' '

  zip: ->
    arrays = map -> it, arguments
    sizes = arrays.map -> it.length
    size = maximum sizes
    [til size].map (_, i) ->
      arrays.map (array) -> array[i]

  paths_color: ->
    [
      ['bold', 'cyan'],
      ['bold', 'green'],
      ['bold', 'magenta'],
      ['white']
    ]

files_to_shot = (paths, dir) ->
  files = fixtures.files_of dir
  files = files.filter (file) ->
    not paths.has_snapshots file
  files

shot_fixtures = (dir, files, cb, done) ->
  paths = new Paths dir, files
  files = files_to_shot paths, dir
  funcs = files.map (file) ->
    (done) ->
      setup_nock_by paths, dir, file
      snapshots <- fixtures.shot_snapshots_of dir, file
      snapshots = build_snapshots dir, file, snapshots
      cassettes = nock.recorder.play!
      cassettes = build_cassettes dir, file, cassettes
      print_fixtures_shoot paths, file
      cb cassettes, snapshots
      shutdown_nock!
      done!
  err, res <- async.series funcs
  throw that if err
  done!

setup_nock_by = (paths, dir, file) ->
  if paths.has_cassettes file
    nock.disable-net-connect!
    nock.define fixtures.load_cassettes dir, file
  else
    nock.enable-net-connect!
  nock.recorder.rec do
    dont_print: true
    output_objects: true

build_cassettes = (dir, file, cassettes) ->
  new File do
    cwd:  fixtures.cwd!
    base: fixtures.base!
    path: fixtures.cassettes_of dir, file
    contents: new Buffer YAML.stringify cassettes

build_snapshots = (dir, file, snapshots) ->
  new File do
    cwd:  fixtures.cwd!
    base: fixtures.base!
    path: fixtures.snapshots_of dir, file
    contents: new Buffer YAML.stringify snapshots

print_fixtures_shoot = (paths, file) ->
  if paths.has_cassettes file
    console.log "#{paths.colorize_snapshots file} #{'-- shoot by using cassettes'.grey}"
  else
    console.log "#{paths.colorize_cassettes file} #{'-- shoot by using network'.grey}"
    console.log "#{paths.colorize_snapshots file} #{'-- shoot by using network'.grey}"

shutdown_nock = ->
  nock.recorder.clear!
  nock.restore!
