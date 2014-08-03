require! <[async]>
require! \../recorders/fixtures
helper = require \../test_helper

export snapshots_should_same = (dir) -> ``it``
  .. 'crawled data should be same as the data crawled before' (done) ->
    files = fixtures.files_of dir
    funcs = files.map (file) ->
      (done) ->
        snapshots <- helper.use_cassettes dir, file
        objs <- fixtures.shot_snapshots_of dir, file
        objs.should.deep.eq snapshots
        done!
    err, res <- async.series funcs
    throw that if err
    done!
