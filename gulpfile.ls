require! <[gulp]>
require! <[./test/recorders/gulp-record]>

['calendar'].map (dir) ->
  gulp.task "shot:#dir" ->
    gulp
    .src [
      * "./test/fixtures/cassettes/#dir/*.yml"
      * "./test/fixtures/snapshots/#dir/*.yml"
    ]
    .pipe gulp-record dir
    .pipe gulp.dest './test/fixtures'
