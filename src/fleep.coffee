{Robot, Adapter, TextMessage} = require 'hubot'

EventEmitter = require('events').EventEmitter

Util = require './util'
FleepClient = require './fleepClient'


class Fleep extends Adapter
  
  constructor: (robot) ->
    super robot

  # Send a message to the chat room where the envelope originated
  send: (envelope, strings...) ->
    for message in strings
      @fleepClient.send message, envelope
  
  # Send a 1:1 message to the user who sent the envelope
  reply: (envelope, strings...) ->
    for message in strings
      @fleepClient.reply message, envelope

  topic: (envelope, strings...) ->
    @fleepClient.topic envelope.room, strings.toString()

  # Public: Dispatch a received message to the robot.
  #
  # Returns nothing.
  receive: (message) ->
    @robot.logger.info 'Patching message to Robot: '+message
    @robot.receive message

  initBrain: =>
    @robot.brain.setAutoSave true
    @robot.logger.debug 'Robot brain connected.'
    @fleepClient.login @options.email, @options.password

  run: ->

    @robot.logger.info 'Starting Hubot with the Fleep.io adapter...'
    @options = Util.parseOptions()

    # Check that Fleep account details have been provided
    unless @options.email?
      @robot.logger.emergency 'You must specify HUBOT_FLEEP_EMAIL'
      process.exit(1)
    unless @options.password?
      @robot.logger.emergency 'You must specify HUBOT_FLEEP_PASSWORD'
      process.exit(1)

    @fleepClient = new FleepClient {
      name: @robot.name,
      markSeen: @options.markSeen
      }, @robot
    
    @fleepClient.on 'connected', =>
      @robot.logger.debug 'Connected, syncing...'
      @fleepClient.sync()
      
    @fleepClient.on 'synced', =>
      @robot.logger.info 'Synced, starting polling'
      @fleepClient.poll()
      
    @fleepClient.on 'gotMessage', (author, message) =>
      @receive new TextMessage(author, message)

    @brainLoaded = false
    @robot.brain.on 'loaded', =>
      if not @brainLoaded
        @brainLoaded = true
        @initBrain()


    @emit 'connected'

  close: ->
    @fleepClient.logout

exports.use = (robot) ->
  new Fleep robot
