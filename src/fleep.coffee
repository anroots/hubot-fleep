{Robot, Adapter, TextMessage} = require 'hubot'

EventEmitter = require('events').EventEmitter

Util = require './util'
FleepClient = require './fleepClient'


class Fleep extends Adapter
  constructor: (robot) ->
    super robot

  send: (envelope, strings...) ->
    message = strings[0]
    Util.log 'Sending Hubot message: '+message
    @fleepClient.send message, envelope.room

  reply: (envelope, strings...) ->
    Util.log 'Sending Hubot reply'

  topic: (params, strings...) ->
    Util.log 'Hubot: changing topic'
    @fleepClient.topic params.room, strings[0]


  # Public: Dispatch a received message to the robot.
  #
  # Returns nothing.
  receive: (message) ->
    Util.log 'Patching message to Robot: '+message
    @robot.receive message

  initBrain: =>
    @robot.brain.setAutoSave true
    Util.debug 'Robot brain connected.'
    @fleepClient.login @options.email, @options.password

  run: ->

    Util.log 'Starting Hubot with the Fleep.io adapter...'
    @options = Util.parseOptions()
    Util.debug 'Adapter options:'
    Util.debug @options

    return Util.logError 'No email provided to Hubot' unless @options.email
    return Util.logError 'No password provided to Hubot' unless @options.password

    @fleepClient = new FleepClient {name: @robot.name}, @robot
    
    @fleepClient.on 'connected', =>
      Util.debug 'Connected, syncing...'
      @fleepClient.sync()
      
    @fleepClient.on 'synced', =>
      Util.log 'Synced, starting polling'
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
