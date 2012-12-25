{{Types: {ObjectId}}:Schema} = mongoose = require \mongoose
findOrCreate = require 'mongoose-findorcreate'

MLY = new Schema do
    name:    String
    party:   String

Proposer = do
    caucus: [String]
    mly_primary: [type: ObjectId, ref: 'MLY']
    mly_seconder: [type: ObjectId, ref: 'MLY']
    government: String
    text: String

Bill = new Schema do
    billNo: String
    type: String
    summary: String
    proposer: Proposer

Bill.plugin findOrCreate

Sitting = do
    committee: String
    ad: Number
    session: Number
    sitting: Number
    extra: Boolean

Motion = new Schema do
    item: Number
    agendaItem: Number
    bill: [{type: ObjectId, ref: 'Bill'}]
    resolution: String
    committee: String

Announcement = new Schema do
    sitting: Sitting
    items: [Motion]

Discussion = new Schema do
    meeting: Sitting
    items: [Motion]

module.exports = { [name, mongoose.model name, s] for name, s of { MLY, Bill, Announcement, Discussion } }
