{EventEmitter} = require 'events'

WebRequest = require './webRequest'
Util = require './util'

module.exports = class FleepClient extends EventEmitter
  
  constructor: (options, @robot) ->
    
    @conversations = options.conversations
    @name = options.name
    
    @ticket = null
    @token_id = null

    @profile = 
      account_id : null,
      display_name : null

    @on 'pollcomplete', (resp) =>
      Util.debug 'Poll complete'
      @handleStreamEvents resp
      Util.debug 'Sending new poll request'
      @poll()

    
  post: (path, body, callback) ->
    WebRequest.request path, body, callback, @ticket, @token_id

  getLastEventHorizon: ->
    last = @robot.brain.get 'fleep_last_horizon'
    Util.debug 'Last event horizon from robot brain: '+last
    last or 0
    
  setLastEventHorizon: (horizon) ->
    @robot.brain.set 'fleep_last_horizon', horizon

  login: (email, password) =>
    Util.debug 'Attempting to log in...'
    
    @post 'account/login', {email: email, password: password}, (err, resp, metaData) =>
      
      if resp.ticket?
        Util.debug "Login returned ticket #{resp.ticket}"
        @ticket = resp.ticket
      
      if metaData.token_id?
        Util.debug "Login returned token_id cookie #{metaData.token_id}"
        @token_id = metaData.token_id

      @profile.account_id = resp.account_id
      @profile.display_name = resp.display_name

      # Tell Hubot we're connected so it can load scripts
      Util.log "Successfully connected Bot #{@name} with Fleep"
      @emit 'connected'

  handleStreamEvents: (resp) =>
    if resp.stream? and resp.stream.length
      @handleStreamEvent event for event in resp.stream
    else
      Util.debug 'Response stream length 0, nothing to parse.'
    if resp.event_horizon?
      @setLastEventHorizon resp.event_horizon
      Util.debug 'Updating last seen event horizon to '+resp.event_horizon
    Util.debug 'Finished handling long poll response'

  handleStreamEvent: (event) =>

    if not event.mk_rec_type?
      Util.logError 'Invalid response from the server'

    if event.mk_rec_type is 'contact'
      Util.debug event
      return
    if event.mk_rec_type isnt 'message'
      Util.debug 'Skipping stream item '+event.mk_rec_type+', not a message type of event'
      return

    if event.conversation_id not in @conversations
      Util.debug 'Skipping stream item '+event.mk_rec_type+', not in a list of monitored conversations'
      return
    
    if event.account_id is @profile.account_id
      Util.debug 'It is my own message, ignore it'
      return
      
    message = event.message.replace(/(<([^>]+)>)/ig,"")
    @markRead event.conversation_id, event.message_nr
    @handleMessage message, event.account_id, event.conversation_id
    
  handleMessage: (message, author_id, conversation_id) =>
    Util.log 'Got message: ' + message

    author = @robot.brain.userForId author_id
    author.room = conversation_id
    author.reply_to = author_id
    
    @emit 'gotMessage', author, message


  poll: =>
    Util.debug 'Starting long poll request'
    data = 
      wait: true,
      event_horizon: @getLastEventHorizon()
      poll_flags: ['skip_hidden']
    @post 'account/poll', data, (err, resp) =>
      @emit 'pollcomplete', resp

  send: (message, conversation_id) =>
    Util.debug 'FleepClient: sending new message to conversation '+conversation_id
    @post "message/send/#{conversation_id}", {message: message}, (err, resp) =>
      Util.debug resp

  markRead: (conversation_id, message_nr) =>
    Util.debug "Marking message #{message_nr} of conversation #{conversation_id} as read"
    @post "message/mark_read/#{conversation_id}", {message_nr: message_nr}, (err, resp) =>
      Util.debug 'Message marked as read.'

  topic: (conversation_id, topic) =>
    Util.debug "Setting conversation #{conversation_id} topic to #{topic}"
    @post "conversation/set_topic/#{conversation_id}", {topic: topic}, (err,resp) =>
      Util.debug resp

  sync:  =>
    Util.debug "Syncing..."
    @post 'account/sync', {}, (err, resp) =>
      Util.debug 'Syncing conversation response'
      @setLastEventHorizon resp.event_horizon
      @emit 'synced'