{Robot, Adapter, TextMessage} = require 'hubot'

EventEmitter = require('events').EventEmitter

Util = require './util'
FleepClient = require './fleepClient'


class Fleep extends Adapter
  
  constructor: (robot) ->
    super robot

  send: (envelope, strings...) ->
    message = strings[0]
    @robot.logger.info 'Sending Hubot message: '+message
    @fleepClient.send message, envelope.room

  reply: (envelope, strings...) ->
    @robot.logger.info 'Sending Hubot reply'

  topic: (params, strings...) ->
    @robot.logger.info 'Hubot: changing topic'
    @fleepClient.topic params.room, strings[0]


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
    @robot.logger.debug 'Adapter options:'
    @robot.logger.debug @options

    return @robot.logger.emergency 'Specify Fleep email' unless @options.email
    return @robot.logger.emergency 'Specify Fleep password' unless @options.password

    @fleepClient = new FleepClient {name: @robot.name}, @robot
    
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



exports.use = (robot) ->
  new Fleep robot
