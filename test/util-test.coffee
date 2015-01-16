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

describe 'isImageUri', ->

  it 'should return false on non-image links', ->
    imageUrls = [
      'http://img4.wikia.nocookie.net/__cb20/charmed/images/2/28/Something',
      '',
      'runescape.com/character.jpg'
    ]

    for url in imageUrls
      expect(util.isImageUri url).to.be.false

  it 'should return true on image links', ->
    imageUrls = [
      'http://www.google.com/logo.png',
      'https://www.google.com/accounts/signup/banner.jpeg',
      'http://bing.com/google/redirect/leaving-so-soon.gif'
    ]

    for url in imageUrls
      expect(util.isImageUri url).to.be.true