require! <[nock]>
require! \./recorders/fixtures
YAML = require \yamljs

export use_cassettes = (dir, file, cb) ->
  nock.disableNetConnect!
  nock.define fixtures.load_cassettes dir, file
  cb fixtures.load_snapshots dir, file
