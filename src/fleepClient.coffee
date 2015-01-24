{EventEmitter} = require 'events'
{TextMessage} = require 'hubot'

WebRequest = require './webRequest'
Util = require './util'
async = require 'async'

module.exports = class FleepClient extends EventEmitter

  constructor: (@options, @robot) ->

    @ticket = null
    @token_id = null

    # Fleep profile info for the bot user
    @profile =
      account_id : null,
      display_name : null

    @on 'pollcomplete', (resp) =>
      @robot.logger.debug 'Poll complete'
      @handleStreamEvents resp
      @poll()

  # Send a POST request to Fleep
  post: (path, body = {}, callback = ->) ->
    request = new WebRequest @robot.logger, @ticket, @token_id
    request.post path, body, (error, response, metaData) =>

      if response.ticket?
        @robot.logger.debug "Response contains ticket: #{response.ticket}"
        @ticket = response.ticket

      if metaData.token_id?
        @robot.logger.debug 'Response contains token_id: ' + metaData.token_id
        @token_id = metaData.token_id

      callback error, response, metaData

  # Return the ID of the last seen Fleep event horizon
  getLastEventHorizon: ->
    last = @robot.brain.get 'fleep_last_horizon'
    @robot.logger.debug 'Last event horizon from robot brain: '+last
    last or 0

  # Set the last seen Fleep event horizon to robot brain
  setLastEventHorizon: (horizon) ->
    @robot.brain.set 'fleep_last_horizon', horizon

  # Login to Fleep with the specified email and password
  # Creates a new session with Fleep and sets the token_id and ticket vars
  login: (email, password) =>
    @robot.logger.debug 'Attempting to log in...'

    @post 'account/login', {
      email: email,
      password: password
      }, (err, resp, metaData) =>

      if err isnt null
        @robot.logger.emergency 'Unable to login to Fleep: ' + err.error_message
        process.exit 1

      # Save Fleep profile info
      @profile.account_id = resp.account_id
      @profile.display_name = resp.display_name

      # Tell Hubot we're connected so it can load scripts
      @robot.logger.info "Successfully connected #{@options.name} with Fleep"
      @emit 'authenticated', @

  # Destroy Fleep session
  logout: ->
    @post 'account/logout', {}, (err, resp) ->
      if err isnt null
        return @robot.logger.error 'Unable to destroy Fleep session'
      @robot.logger.debug 'User session with Fleep closed.'

  # The result of a long poll request to account/poll is passed here
  # Handle all of its 'stream' items (conversations, contacts...) ie
  # events that happened during the poll request
  handleStreamEvents: (resp) =>

    # The poll response gives us our next "last seen" event horizon
    if resp.event_horizon?
      @setLastEventHorizon resp.event_horizon
      @robot.logger.debug 'Updating last seen event horizon to '+
        resp.event_horizon

    # Handle stream items individually
    if resp.stream? and resp.stream.length
      @handleStreamEvent event for event in resp.stream
    else
      @robot.logger.debug 'Response stream length 0, nothing to parse.'
    @robot.logger.debug 'Finished handling long poll response'

  # Save the conversation into the internal "known conversations" list
  # The message number indicates the last known seen message
  saveConversation: (conversation_id, message_nr) =>
    conversations = @getKnownConversations()
    conversations[conversation_id] = {last_message_nr:message_nr}
    @robot.brain.set 'conversations', conversations
    @markRead conversation_id, message_nr

  # Processes a single Event object in a list of Fleep events
  handleStreamEvent: (event) =>

    @robot.logger.debug 'Handling event: '+JSON.stringify event

    # Event does not have a rec_type, API error?
    if not event.mk_rec_type?
      @robot.logger.error 'Invalid response from the server, no rec_type'
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
    unless @getKnownConversations()?[event.conversation_id]?
      @robot.logger.debug "New conversation! Conversation " +
      "#{event.conversation_id} was not in the list of monitored " +
      "conversations, adding it now"
      @saveConversation event.conversation_id, event.message_nr
      return

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

    # Patch the received text message to Hubot
    @handleMessage event

  # Determines whether a particular message in
  # a particular message has been seen
  isMessageSeen: (conversation_id, message_nr) =>
    @getKnownConversations()?[conversation_id]?['last_message_nr'] >= message_nr

  # Parses an incoming message and passes it to Hubot
  # Message is a Fleep event response object
  handleMessage: (message) =>

    # Do nothing if the message is already seen
    return if @isMessageSeen message.conversation_id, message.message_nr

    # Strip HTML tags
    text = message.message.replace(/(<([^>]+)>)/ig,"")

    # Mark message as read
    @markRead message.conversation_id, message.message_nr

    @robot.logger.info 'Got message: ' + JSON.stringify message

    # Create a Hubot user object
    author = @robot.brain.userForId message.account_id
    author.room = message.conversation_id
    author.reply_to = message.account_id

    textMessage = new TextMessage author, text
    @emit 'gotMessage', textMessage

  # Send a new long poll request to the Fleep API
  # The request will wait ~90 seconds
  # If new information is available, the server will respond immediately
  poll: =>
    @robot.logger.debug 'Starting long poll request'
    data =
      wait: true,
      event_horizon: @getLastEventHorizon()
      poll_flags: ['skip_hidden']

    @post 'account/poll', data, (err, resp) =>
      @emit 'pollcomplete', resp

  # Send a new message to Fleep
  send: (envelope, message) =>
    @robot.logger.debug 'Sending new message to conversation ' + envelope.room

    @post "message/send/#{envelope.room}", {message: message}, (err, resp) ->
      if err isnt null
        @robot.logger.error 'Unable to send a message: '+JSON.stringify err


  # Send a private message to a user
  reply: (envelope, message) ->
    @robot.logger.debug 'Sending private message to user ' + envelope.user.id

    @post 'conversation/create', {
      topic: null, # Topic is currently empty, the default is the bot's name
      emails:envelope.user.email,
      message: message
    }, (err, resp) ->
      if err isnt null
        @robot.logger.error 'Unable to send a 1:1 message: '+JSON.stringify err

  # Get a hash of known conversations
  getKnownConversations: =>
    @robot.brain.get('conversations') ? {}

  # Mark a Fleep message as 'seen' by the bot
  markRead: (conversation_id, message_nr) =>

    # Save the last message number into an internal tracker
    conversations = @robot.brain.get 'conversations'
    conversations[conversation_id]['last_message_nr'] = message_nr
    @robot.brain.set 'conversations', conversations

    # Do not mark it as 'seen' in Fleep if not enabled
    return unless @options.markSeen

    @robot.logger.debug "Marking message #{message_nr} of conversation " +
    "#{conversation_id} as read"
    @post "message/mark_read/#{conversation_id}", {
      message_nr: message_nr
      }, (err, resp) ->
      @robot.logger.debug 'Message marked as read.' if err is null

  # Change the topic of a conversation
  topic: (conversation_id, topic) =>
    @robot.logger.debug "Setting conversation #{conversation_id} "+
    "topic to #{topic}"
    @post "conversation/set_topic/#{conversation_id}", {
      topic: topic
      }, (err,resp) ->
      @robot.logger.error 'Unable to set topic' if err isnt null

  # Syncs the list of known conversations
  populateConversationList: (callback) =>
    @post 'conversation/list', {sync_horizon: 0}, (err, resp) =>
      unless resp.conversations? and resp.conversations.length
        return

      for conv in resp.conversations
        unless @getKnownConversations()?[conv.conversation_id]?
          @saveConversation conv.conversation_id, conv.last_message_nr
      @robot.logger.debug 'Conversation list synced'
      callback()

  # Sync last seen event horizon
  syncEventHorizon: (callback) =>
    @post 'account/sync', {}, (err, resp) =>
      @setLastEventHorizon resp.event_horizon
      @robot.logger.debug 'Event horizon synced'
      callback()

  # Change the Fleep user name to the Bot name
  changeNick: (callback) =>
    @post 'account/configure', {display_name: @options.name}, (err, resp) =>
      @robot.logger.debug resp
      @robot.logger.debug 'Nick changed'
      callback()

  # Sync the list of known contacts
  syncContacts: (callback) =>
    @post 'contact/sync/all', {ignore: []}, (err, resp) =>
      @handleStreamEvent contact for contact in resp.contacts
      @robot.logger.debug 'Contacts in sync'
      callback()

  # Synchronizes some initial data with Fleep
  # list of conversations / bot nick / contacts / event_horizon
  sync:  =>

    @robot.logger.debug "Syncing..."

    # Does synchronization operations in parallel
    # Calls the callback function only if all operations are complete
    async.parallel [
      (cb) => @populateConversationList cb,
      (cb) => @syncEventHorizon cb,
      (cb) => @changeNick cb,
      (cb) => @syncContacts cb
    ], (err, results) =>
      if err isnt null
        @robot.logger.error 'Error during data sync: '+JSON.stringify err
      @robot.logger.debug 'Everything synced, ready to go!'
      @emit 'synced', @

