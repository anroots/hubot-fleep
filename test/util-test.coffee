chai = require 'chai'
util = require '../src/util'

expect = chai.expect
chai.should()
describe 'merge', ->
  
  it 'should return an empty object if inputs are empty', ->
    util.merge({}, {}, {}).should.be.empty()
