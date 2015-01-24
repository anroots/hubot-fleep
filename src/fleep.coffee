{Robot, Adapter} = require 'hubot'

EventEmitter = require('events').EventEmitter
Util = require './util'
FleepClient = require './fleepClient'

class Fleep extends Adapter

  # Adapter constructor
  constructor: (robot) ->

    # Call parent constructor
    super robot

    @brainLoaded = false

    # Parse environment options into a usable object
    @options = Util.parseOptions()

    # Construct a new instance of FleepClient
    # The client will be the class doing most of the hard work of
    # passing requests to and from Fleep
    @fleepClient = new FleepClient {
      name: @robot.name,
      markSeen: @options.markSeen,
      uploadImages: @options.uploadImages
    }, @robot


  # Send a message to the chat room where the envelope originated
  send: (envelope, messages...) ->
    @fleepClient.send envelope, message for message in messages

  # Send a 1:1 message (a private message) to the user who sent the envelope
  reply: (envelope, messages...) ->
    @fleepClient.reply envelope, message for message in messages

  # Change conversation topic
  topic: (envelope, topics...) ->
    @fleepClient.topic envelope.room, topics.join ' / '

  # Public: Dispatch a received message to the robot.
  receive: (message) ->
    @robot.receive message

  run: ->

    @robot.logger.info 'Starting Hubot with the Fleep.io adapter...'

    # Check that Fleep account details have been provided
    unless @options.email?
      @robot.logger.emergency 'You must specify HUBOT_FLEEP_EMAIL'
      process.exit 1
    unless @options.password?
      @robot.logger.emergency 'You must specify HUBOT_FLEEP_PASSWORD'
      process.exit 1

    # When FleepClient has authenticated against Fleep and is ready to continue
    # Do initial data sync between the Hubot and Fleep
    @fleepClient.on 'authenticated', (client) ->
      client.sync()

    # When initial data sync (read messages, contacts etc) is done
    # Start long polling cycle
    @fleepClient.on 'synced', (client) ->
      client.poll()

    # Got a message from Fleep
    @fleepClient.on 'gotMessage', (message) =>
      @receive message

    # Only login to Fleep once the brain has loaded
    @robot.brain.on 'loaded', =>

      # Do this only once
      return if @brainLoaded

      @brainLoaded = true

      @robot.logger.debug 'Robot brain connected.'
      @robot.brain.setAutoSave true
      @fleepClient.login @options.email, @options.password


    @emit 'connected'

  # Logout from Fleep when the session is closed
  close: ->
    @fleepClient.logout()

exports.use = (robot) ->
  new Fleep robot
