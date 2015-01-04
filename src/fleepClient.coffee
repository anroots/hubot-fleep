{EventEmitter} = require 'events'

WebRequest = require './webRequest'
Util = require './util'

module.exports = class FleepClient extends EventEmitter
  
  constructor: (options, @robot) ->
    
    @conversations = []
    @name = options.name
    
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

    
  post: (path, body, callback) ->
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
      @robot.logger.info "Successfully connected Bot #{@name} with Fleep"
      @emit 'connected'

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

    # Event does not have a rec_type, API error?
    if not event.mk_rec_type?
      @robot.logger.error 'Invalid response from the server'
      return

    # New contact information, currently we don't do anything with it
    if event.mk_rec_type is 'contact'
      @robot.logger.debug event
      return

    # Skip everything but text message events
    if event.mk_rec_type isnt 'message'
      @robot.logger.debug 'Skipping stream item ' +
      event.mk_rec_type + ', not a messag-e type of event'
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
      @robot.logger.error 'Invalid API response from the server!'
      @robot.logger.debug event
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

  send: (message, conversation_id) =>
    @robot.logger.debug 'Sending new message to conversation ' + conversation_id
    @post "message/send/#{conversation_id}", {message: message}, (err, resp) ->
      @robot.logger.debug resp

  markRead: (conversation_id, message_nr) =>
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
    @post 'account/configure', {display_name: @name}, (err, resp) ->
      @robot.logger.debug resp