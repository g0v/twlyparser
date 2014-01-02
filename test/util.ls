should = require \chai .should!

{get-sitting} = require \../lib/util

describe 'get-sitting' ->
  describe 'is excepted to return sitting structure' -> ``it``
    .. 'committee sitting with co-committee' (done) ->
      res = get-sitting "立法院第8屆第4會期外交及國防、經濟兩委員會第2次聯席會議"
      res.committee.should.deep.eq <[ FND ECO ]>
      res<[ad session sitting]>.should.deep.eq [8 4 2]
      done!
    .. 'hearing' (done) ->
      res = get-sitting "立法院第8屆第4會期內政、外交及國防、經濟、財政、教育及文化、交通、司法及法制、社會福利及衛生環境委員會「海峽兩岸服務貿易協議」公聽會（第十場）"
      res.hearing.should.eq '海峽兩岸服務貿易協議'
      res.committee.should.deep.eq <[IAD FND ECO FIN EDU TRA JUD SWE]>
      res<[ad session sitting]>.should.deep.eq [8 4 10]
      done!
    .. 'hearing' (done) ->
      res = get-sitting "立法院第8屆第4會期內政、司法及法制二委員會第1次聯席會議"
      res.committee.should.deep.eq <[IAD JUD]>
      res<[ad session sitting]>.should.deep.eq [8 4 1]
      done!
