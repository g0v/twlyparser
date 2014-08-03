require \chai .should!
require! \../support/record

describe 'ly' ->
  describe 'calendar' ->

    record.snapshots_should_same @title
