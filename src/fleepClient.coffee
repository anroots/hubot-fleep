{EventEmitter} = require 'events'

WebRequest = require './webRequest'
Util = require './util'

module.exports = class FleepClient extends EventEmitter
  
  constructor: (@options, @robot) ->
    
    @conversations = []
    
    @ticket = null
    @token_id = null

    @profile =
      account_id : null,
      display_name : null

    @on 'pollcomplete', (resp) =>
      @robot.logger.debug 'Poll complete'
      @handleStreamEvents resp
      @robot.logger.debug 'Sending new poll request'
      @poll()

    
  post: (path, body = {}, callback) ->
    request = new WebRequest(@robot.logger)
    request.post path, body, callback, @ticket, @token_id

  getLastEventHorizon: ->
    last = @robot.brain.get 'fleep_last_horizon'
    @robot.logger.debug 'Last event horizon from robot brain: '+last
    last or 0
    
  setLastEventHorizon: (horizon) ->
    @robot.brain.set 'fleep_last_horizon', horizon

  login: (email, password) =>
    @robot.logger.debug 'Attempting to log in...'
    
    @post 'account/login', {
      email: email,
      password: password
      }, (err, resp, metaData) =>
      
      if resp.ticket?
        @robot.logger.debug "Login returned ticket #{resp.ticket}"
        @ticket = resp.ticket
      
      if metaData.token_id?
        @robot.logger.debug 'Login returned token_id cookie:'+metaData.token_id
        @token_id = metaData.token_id

      @profile.account_id = resp.account_id
      @profile.display_name = resp.display_name

      # Tell Hubot we're connected so it can load scripts
      @robot.logger.info "Successfully connected #{@options.name} with Fleep"
      @emit 'connected'

  logout: ->
    @post 'account/logout', {}, (err, resp) ->
      @robot.logger.debug 'User session with Fleep closed.'
      
  handleStreamEvents: (resp) =>
    if resp.stream? and resp.stream.length
      @handleStreamEvent event for event in resp.stream
    else
      @robot.logger.debug 'Response stream length 0, nothing to parse.'
    if resp.event_horizon?
      @setLastEventHorizon resp.event_horizon
      @robot.logger.debug 'Updating last seen event horizon to '+
      resp.event_horizon
    @robot.logger.debug 'Finished handling long poll response'


  # Processes a single Event object in a list of Fleep events
  handleStreamEvent: (event) =>

    @robot.logger.debug event

    # Event does not have a rec_type, API error?
    if not event.mk_rec_type?
      @robot.logger.error 'Invalid response from the server'
      return

    # New contact information
    if event.mk_rec_type is 'contact'
      user = @robot.brain.userForId event.account_id

      # Save the contact name if it's currently unknown
      if not user.name? or user.name is user.id
        user.name = event.display_name
        @robot.logger.debug "New contact: id #{user.id}, name #{user.name}"

      if not user.email? and event.email?
        user.email = event.email

      return

    # Skip everything but text message events
    if event.mk_rec_type isnt 'message'
      @robot.logger.debug 'Skipping stream item ' +
      event.mk_rec_type + ', not a message type of event'
      return

    # Detected a new conversation
    if event.conversation_id not in @conversations
      @robot.logger.debug "New conversation! Conversation " +
      "#{event.conversation_id} was not in the list of monitored " +
      "conversations, adding it now"
      @conversations.push event.conversation_id
    
    # This message is an echo of our own message, ignore
    if event.account_id is @profile.account_id
      @robot.logger.debug 'It is my own message, ignore it'
      return

    # Ignore edited messages (messages that were posted, then edited)
    # See https://github.com/anroots/hubot-fleep/issues/4
    if event.revision_message_nr?
      @robot.logger.debug 'This is an edited message, skipping...'
      return

    # Ignore messages without the 'message' key - some invalid state
    if not event.message?
      @robot.logger.error 'Invalid API response from the server!' +
      ' Expected a "message" key.'
      return

    message = event.message.replace(/(<([^>]+)>)/ig,"")
    @markRead event.conversation_id, event.message_nr
    @handleMessage message, event.account_id, event.conversation_id
    
  handleMessage: (message, author_id, conversation_id) =>
    @robot.logger.info 'Got message: ' + message

    author = @robot.brain.userForId author_id
    author.room = conversation_id
    author.reply_to = author_id

    @emit 'gotMessage', author, message

  poll: =>
    @robot.logger.debug 'Starting long poll request'
    data =
      wait: true,
      event_horizon: @getLastEventHorizon()
      poll_flags: ['skip_hidden']
    @post 'account/poll', data, (err, resp) =>
      @emit 'pollcomplete', resp

  send: (message, envelope) =>
    @robot.logger.debug 'Sending new message to conversation ' + envelope.room
    @post "message/send/#{envelope.room}", {message: message}, (err, resp) ->
      @robot.logger.debug 'Callback for send called'

  reply: (message, envelope) ->
    @robot.logger.debug 'Sending private message to user ' + envelope.user.id
    @post 'conversation/create', {
      topic: null, # Topic is currently empty, the default is the bot's name
      emails:envelope.user.email,
      message: message
    }, (err, resp) ->
      @robot.logger.debug 'Callback for reply called'


  markRead: (conversation_id, message_nr) =>
    return unless @options.markSeen

    @robot.logger.debug "Marking message #{message_nr} of conversation " +
    "#{conversation_id} as read"
    @post "message/mark_read/#{conversation_id}", {
      message_nr: message_nr
      }, (err, resp) ->
      @robot.logger.debug 'Message marked as read.'

  topic: (conversation_id, topic) =>
    @robot.logger.debug "Setting conversation #{conversation_id} "+
    "topic to #{topic}"
    @post "conversation/set_topic/#{conversation_id}", {
      topic: topic
      }, (err,resp) ->
      @robot.logger.debug resp

  sync:  =>
    @robot.logger.debug "Syncing..."
    @post 'account/sync', {}, (err, resp) =>
      @robot.logger.debug 'Syncing conversation response'
      @setLastEventHorizon resp.event_horizon
      @emit 'synced'
    
    @robot.logger.debug "Changing bot nick"
    @post 'account/configure', {display_name: @options.name}, (err, resp) ->
      @robot.logger.debug resp

    # Fetch contact info
    @robot.logger.debug "Syncing contacts"
    @post 'contact/sync/all', {ignore: []}, (err, resp) =>
      @handleStreamEvent contact for contact in resp.contacts