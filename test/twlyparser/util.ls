should = require \chai .should!

{get-sitting} = require \../../lib/util

describe 'get-sitting' ->
  describe 'hearing is excepted to return sitting structure' -> ``it``
    .. 'hearing' (done) ->
      res = get-sitting "立法院第8屆第4會期內政、外交及國防、經濟、財政、教育及文化、交通、司法及法制、社會福利及衛生環境委員會「海峽兩岸服務貿易協議」公聽會（第十場）"
      res.hearing.should.eq '海峽兩岸服務貿易協議'
      res.committee.should.deep.eq <[IAD FND ECO FIN EDU TRA JUD SWE]>
      res<[ad session sitting]>.should.deep.eq [8 4 10]
      done!
    .. 'hearing' (done) ->
      res = get-sitting "立法院第8屆第4會期內政、外交及國防、經濟、財政、教育及文化、交通、司法及法制、社會福利及衛生環境八委員會召開「海峽兩岸服務貿易協議」公聽會(第七場)會議"
      res.hearing.should.eq '海峽兩岸服務貿易協議'
      res.committee.should.deep.eq <[IAD FND ECO FIN EDU TRA JUD SWE]>
      res<[ad session sitting]>.should.deep.eq [8 4 7]
      done!
    .. 'hearing' (done) ->
      res = get-sitting "立法院第8屆第4會期司法及法制委員會「通訊保障及監察法部分條文修正草案」公聽會"
      res.hearing.should.eq '通訊保障及監察法部分條文修正草案'
      res.committee.should.deep.eq <[JUD]>
      res<[ad session sitting]>.should.deep.eq [8 4 void]
      done!
    .. 'hearing' (done) ->
      res = get-sitting "立法院第8屆第1會期第1次全院委員會「行使考試院副院長及考試委員同意權」公聽會會議"
      res.hearing.should.eq '行使考試院副院長及考試委員同意權'
      res.committee.should.deep.eq <[WHL]>
      res<[ad session sitting]>.should.deep.eq [8 1 1]
      done!
    .. 'hearing' (done) ->
      res = get-sitting "立法院第8屆第4會期司法及法制委員會「通訊保障及監察法部分條文修正草案」公聽會"
      res.hearing.should.eq '通訊保障及監察法部分條文修正草案'
      res.committee.should.deep.eq <[JUD]>
      res<[ad session sitting]>.should.deep.eq [8 4 void]
      done!
    .. 'hearing' (done) ->
      res = get-sitting "立法院第8屆第3會期第1次臨時會內政委員會「大陸地區處理兩岸人民往來事務機構在臺灣地區設立分支機構條例草案」公聽會會議"
      res.hearing.should.eq '大陸地區處理兩岸人民往來事務機構在臺灣地區設立分支機構條例草案'
      res.committee.should.deep.eq <[IAD]>
      res<[ad session extra]>.should.deep.eq [8 3 1]
      done!
    .. 'hearing' (done) ->
      res = get-sitting "立法院社會福利及衛生環境委員會舉行「《職業災害勞工保護法》關於職災津貼補助計算方式、職災補助是否適用所有外籍勞工、政府是否向雇主代位求償、放寬津貼請領年限及失能等級認定、職業傷病認定鑑定委員會組成成員與方式等修法議題」公聽會會議"
      res.hearing.should.eq '《職業災害勞工保護法》關於職災津貼補助計算方式、職災補助是否適用所有外籍勞工、政府是否向雇主代位求償、放寬津貼請領年限及失能等級認定、職業傷病認定鑑定委員會組成成員與方式等修法議題'
      res.committee.should.deep.eq <[SWE]>
      done!
  describe 'committee is excepted to return sitting structure' -> ``it``
    .. 'coc-ommittee' (done) ->
      res = get-sitting "立法院第8屆第4會期內政、司法及法制二委員會第1次聯席會議"
      res.committee.should.deep.eq <[IAD JUD]>
      res<[ad session sitting]>.should.deep.eq [8 4 1]
      done!
    .. 'committee' (done) ->
      res = get-sitting "立法院第8屆第4會期司法及法制委員會第18次全體委員會議"
      res.committee.should.deep.eq <[JUD]>
      res<[ad session sitting]>.should.deep.eq [8 4 18]
      done!
    .. 'committee sitting with co-committee' (done) ->
      res = get-sitting "立法院第8屆第4會期外交及國防、經濟兩委員會第2次聯席會議"
      res.committee.should.deep.eq <[ FND ECO ]>
      res<[ad session sitting]>.should.deep.eq [8 4 2]
      done!
