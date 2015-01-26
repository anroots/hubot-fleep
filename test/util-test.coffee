chai = require 'chai'
util = require '../src/util'

expect = chai.expect
chai.should()

describe 'merge', ->
  
  it 'should return an empty object if inputs are empty', ->
    util.merge({}, {}, {}).should.be.empty()
  
  it 'should merge two objects', ->
    expected = {dog: 'Ben', cat: 'Anne'}
    result = util.merge {dog: 'Ben'}, {cat: 'Anne'}
    expect(result).to.deep.equal expected

  it 'should override existing object keys', ->
    expected = {dog:'Ridley', cat: 'Anne'}
    result = util.merge {dog: 'Ben', 'cat': 'Anne'}, {dog: 'Ridley'}
    expect(result).to.deep.equal expected