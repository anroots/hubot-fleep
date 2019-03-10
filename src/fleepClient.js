/*
 * decaffeinate suggestions:
 * DS001: Remove Babel/TypeScript constructor workaround
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS103: Rewrite code to no longer use __guard__
 * DS104: Avoid inline assignments
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
let FleepClient;
const {EventEmitter} = require('events');
const {TextMessage, EnterMessage, LeaveMessage, TopicMessage} = require('hubot');

const WebRequest = require('./webRequest');
const Util = require('./util');
const async = require('async');
const S = require('string');

module.exports = (FleepClient = class FleepClient extends EventEmitter {

  constructor(options, robot) {

    {
      // Hack: trick Babel/TypeScript into allowing this before super.
      if (false) { super(); }
      let thisFn = (() => { return this; }).toString();
      let thisName = thisFn.match(/return (?:_assertThisInitialized\()*(\w+)\)*;/)[1];
      eval(`${thisName} = this;`);
    }
    this.login = this.login.bind(this);
    this.handleStreamEvents = this.handleStreamEvents.bind(this);
    this.saveConversation = this.saveConversation.bind(this);
    this.handleStreamEvent = this.handleStreamEvent.bind(this);
    this.isMessageSeen = this.isMessageSeen.bind(this);
    this.handleMessage = this.handleMessage.bind(this);
    this.poll = this.poll.bind(this);
    this.send = this.send.bind(this);
    this.getKnownConversations = this.getKnownConversations.bind(this);
    this.markRead = this.markRead.bind(this);
    this.topic = this.topic.bind(this);
    this.populateConversationList = this.populateConversationList.bind(this);
    this.syncEventHorizon = this.syncEventHorizon.bind(this);
    this.changeNick = this.changeNick.bind(this);
    this.syncContacts = this.syncContacts.bind(this);
    this.sync = this.sync.bind(this);
    this.options = options;
    this.robot = robot;
    this.ticket = null;
    this.token_id = null;

    // Fleep profile info for the bot user
    this.profile = {
      account_id : null,
      display_name : null
    };

    this.on('pollcomplete', resp => {
      this.robot.logger.debug('Poll complete');
      this.handleStreamEvents(resp);
      return this.poll();
    });
  }

  // Send a POST request to Fleep
  post(path, body, callback) {
    if (body == null) { body = {}; }
    if (callback == null) { callback = function() {}; }
    const request = new WebRequest(this.robot.logger, this.ticket, this.token_id);
    return request.post(path, body, (error, response, metaData) => {

      if ((response != null ? response.ticket : undefined) != null) {
        this.robot.logger.debug(`Response contains ticket: ${response.ticket}`);
        this.ticket = response.ticket;
      }

      if ((metaData != null ? metaData.token_id : undefined) != null) {
        this.robot.logger.debug(`Response contains token_id: ${metaData.token_id}`);
        this.token_id = metaData.token_id;
      }

      return callback(error, response, metaData);
    });
  }

  // Return the ID of the last seen Fleep event horizon
  getLastEventHorizon() {
    const last = this.robot.brain.get('fleep_last_horizon');
    this.robot.logger.debug(`Last event horizon from robot brain: ${last}`);
    return last || 0;
  }

  // Set the last seen Fleep event horizon to robot brain
  setLastEventHorizon(horizon) {
    return this.robot.brain.set('fleep_last_horizon', horizon);
  }

  // Login to Fleep with the specified email and password
  // Creates a new session with Fleep and sets the token_id and ticket vars
  login(email, password) {
    this.robot.logger.debug('Attempting to log in...');

    return this.post('account/login', {
      email,
      password
      }, (err, resp, metaData) => {

      if (err !== null) {
        this.robot.logger.emergency(`Unable to login to Fleep: ${err.error_message}`);
        process.exit(1);
      }

      // Save Fleep profile info
      this.profile.account_id = resp.account_id;
      this.profile.display_name = resp.display_name;

      // Tell Hubot we're connected so it can load scripts
      this.robot.logger.info(`Successfully connected ${this.options.name} with Fleep`);
      return this.emit('authenticated', this);
    });
  }

  // Destroy Fleep session
  logout() {
    return this.post('account/logout', {}, (err, resp) => {
      if (err !== null) {
        return this.robot.logger.error('Unable to destroy Fleep session');
      }
      return this.robot.logger.debug('User session with Fleep closed.');
    });
  }

  // The result of a long poll request to account/poll is passed here
  // Handle all of its 'stream' items (conversations, contacts...) ie
  // events that happened during the poll request
  handleStreamEvents(resp) {

    // The poll response gives us our next "last seen" event horizon
    if (resp.event_horizon != null) {
      this.setLastEventHorizon(resp.event_horizon);
      this.robot.logger.debug('Updating last seen event horizon to '+
        resp.event_horizon
      );
    }

    // Handle stream items individually
    if ((resp.stream != null) && resp.stream.length) {
      for (let event of Array.from(resp.stream)) { this.handleStreamEvent(event); }
    } else {
      this.robot.logger.debug('Response stream length 0, nothing to parse.');
    }
    return this.robot.logger.debug('Finished handling long poll response');
  }

  // Save the conversation into the internal "known conversations" list
  // The message number indicates the last known seen message
  saveConversation(conversation_id, message_nr) {
    const conversations = this.getKnownConversations();
    conversations[conversation_id] = {last_message_nr:message_nr};
    this.robot.brain.set('conversations', conversations);
    return this.markRead(conversation_id, message_nr);
  }

  // Processes a single Event object in a list of Fleep events
  handleStreamEvent(event) {

    this.robot.logger.debug(`Handling event: ${JSON.stringify(event)}`);

    const eventRecType = event.mk_rec_type || null;

    // Event does not have a rec_type, API error?
    if (eventRecType === null) {
      this.robot.logger.error('Invalid response from the server, no rec_type');
      return;
    }

    // New contact information
    if (eventRecType === 'contact') {
      const user = this.robot.brain.userForId(event.account_id);

      // Save the contact name if it's currently unknown
      if ((user.name == null) || (user.name === user.id)) {
        user.name = event.display_name;
        this.robot.logger.debug(`New contact: id ${user.id}, name ${user.name}`);
      }

      if ((user.email == null) && (event.email != null)) {
        user.email = event.email;
      }

      if ((user.phone_nr == null) && (event.phone_nr != null ? event.phone_nr.length : undefined)) {
        user.phone = event.phone_nr;
      }

      return;
    }

    // Skip everything but text message events
    if (eventRecType !== 'message') {
      this.robot.logger.debug('Skipping stream item ' +
      eventRecType + ', not a message type of event'
      );
      return;
    }

    // Detected a new conversation
    if (__guard__(this.getKnownConversations(), x => x[event.conversation_id]) == null) {
      this.robot.logger.debug("New conversation! Conversation " +
      `${event.conversation_id} was not in the list of monitored ` +
      "conversations, adding it now"
      );
      this.saveConversation(event.conversation_id, event.message_nr);
      return;
    }

    // This message is an echo of our own message, ignore
    if (event.account_id === this.profile.account_id) {
      this.robot.logger.debug('It is my own message, ignore it');
      return;
    }

    // Ignore edited messages (messages that were posted, then edited)
    // See https://github.com/anroots/hubot-fleep/issues/4
    if ((event.revision_message_nr != null) && (event.mk_message_type !== 'topic')) {
      this.robot.logger.debug('This is an edited message, skipping...');
      return;
    }

    // Patch the received text message to Hubot
    return this.handleMessage(event);
  }

  // Determines whether a particular message in
  // a particular message has been seen
  isMessageSeen(conversation_id, message_nr) {
    return __guard__(__guard__(this.getKnownConversations(), x1 => x1[conversation_id]), x => x['last_message_nr']) >= message_nr;
  }

  // Parses an incoming message and passes it to Hubot
  // Message is a Fleep event response object
  handleMessage(message) {

    let messageNumber, senderId;
    let messageText = message.message || null;
    const conversationId = message.conversation_id || null;

    // Extract the message type. One of text|kick|topic|add
    const messageType = message.mk_message_type || null;

    if (messageType === 'topic') {
      // A topic message is funny. It's number is in message_nr
      // unless the topic was edited before some other message was posted.
      // Then we need to fetch it's message number from revision_message_nr
      messageNumber = message.message_nr || message.revision_message_nr;
    } else {
      messageNumber = message.message_nr || null;
    }

    // Do nothing if the message is already seen
    if (this.isMessageSeen(conversationId, messageNumber)) {
      this.robot.logger.debug(`Already seen message ${messageNumber}`);
      return;
    }

    this.robot.logger.info(`Got message: ${JSON.stringify(message)}`);

    if ((messageText !== null) && (messageType === 'text')) {
      // Strip HTML tags and decode HTML entities
      messageText = S(message.message).stripTags().decodeHTMLEntities().s;
    }

    // Mark message as read
    this.markRead(conversationId, messageNumber);

    // Extract sender ID
    if (['kick','add'].includes(messageType)) {
      // Kick and Add messages have the sender encoded
      // as a JSON string in the message key
      senderId = JSON.parse(message.message).members[0];
    } else {
      senderId = message.account_id;
    }

    // Find the user who sent the message
    const user = this.robot.brain.userForId(senderId);

    // A workaround for not saving the room and reply_to info
    // to the robot brain.
    // See https://github.com/hipchat/hubot-hipchat/issues/175
    const author = Util.merge(user, {});

    // Add the room ID where the message came from
    author.room = conversationId;

    // Since private messages are the same as rooms in Fleep,
    // the reply_to is equal to the room where the message was sent
    author.reply_to = conversationId;

    const messageObject = this.createMessage(
      author, messageText, messageType, messageNumber
    );

    return this.emit('gotMessage', messageObject);
  }

  // Returns a correct Message subtype object depending on the message type
  createMessage(author, message, type, messageNumber = null) {
    switch (type) {
      case 'kick':
        this.robot.logger.debug(`${author.name} kicked from ${author.room}`);
        return new LeaveMessage(author);
      case 'add':
        this.robot.logger.debug(`${author.name} joined ${author.room}`);
        return new EnterMessage(author);
      case 'topic':
        var { topic } = JSON.parse(message);
        this.robot.logger.debug(`${author.room} topic is now ${topic}`);
        return new TopicMessage(author, topic, messageNumber);
      default:
        return new TextMessage(author, message, messageNumber);
    }
  }

  // Send a new long poll request to the Fleep API
  // The request will wait ~90 seconds
  // If new information is available, the server will respond immediately
  poll() {
    this.robot.logger.debug('Starting long poll request');
    const data = {
      wait: true,
      event_horizon: this.getLastEventHorizon(),
      poll_flags: ['skip_hidden']
    };

    return this.post('account/poll', data, (err, resp) => {
      return this.emit('pollcomplete', resp);
    });
  }

  // Send a new message to Fleep
  send(envelope, message) {
    this.robot.logger.debug(`Sending new message to conversation ${envelope.room}`);

    return this.post(`message/send/${envelope.room}`, {message}, (err, resp) => {
      if (err !== null) {
        return this.robot.logger.error(`Unable to send a message: ${JSON.stringify(err)}`);
      }
    });
  }


  // Send a private message to a user
  reply(envelope, message) {
    this.robot.logger.debug(`Sending private message to user ${envelope.user.id}`);

    return this.post('conversation/create', {
      topic: null, // Topic is currently empty, the default is the bot's name
      emails:envelope.user.email,
      message
    }, (err, resp) => {
      if (err !== null) {
        return this.robot.logger.error(`Unable to send a 1:1 message: ${JSON.stringify(err)}`);
      }
    });
  }

  // Get a hash of known conversations
  getKnownConversations() {
    let left;
    return (left = this.robot.brain.get('conversations')) != null ? left : {};
  }

  // Mark a Fleep message as 'seen' by the bot
  markRead(conversation_id, message_nr) {

    // Save the last message number into an internal tracker
    const conversations = this.robot.brain.get('conversations');
    conversations[conversation_id]['last_message_nr'] = message_nr;
    this.robot.brain.set('conversations', conversations);

    // Do not mark it as 'seen' in Fleep if not enabled
    if (!this.options.markSeen) { return; }

    this.robot.logger.debug(`Marking message ${message_nr} of conversation ` +
    `${conversation_id} as read`
    );
    return this.post(`message/mark_read/${conversation_id}`, {
      message_nr
      }, (err, resp) => {
      if (err === null) { return this.robot.logger.debug('Message marked as read.'); }
    });
  }

  // Change the topic of a conversation
  topic(conversation_id, topic) {
    this.robot.logger.debug(`Setting conversation ${conversation_id} `+
    `topic to ${topic}`
    );
    return this.post(`conversation/set_topic/${conversation_id}`, {
      topic
      }, (err,resp) => {
      if (err !== null) { return this.robot.logger.error('Unable to set topic'); }
    });
  }

  // Syncs the list of known conversations
  populateConversationList(callback) {
    return this.post('conversation/list', {sync_horizon: 0}, (err, resp) => {
      if ((resp.conversations == null) || !resp.conversations.length) {
        return;
      }

      for (var conv of Array.from(resp.conversations)) {
        if (__guard__(this.getKnownConversations(), x => x[conv.conversation_id]) == null) {
          this.saveConversation(conv.conversation_id, conv.last_message_nr);
        }
      }
      this.robot.logger.debug('Conversation list synced');
      return callback();
    });
  }

  // Sync last seen event horizon
  syncEventHorizon(callback) {
    return this.post('account/sync', {}, (err, resp) => {
      this.setLastEventHorizon(resp.event_horizon);
      this.robot.logger.debug('Event horizon synced');
      return callback();
    });
  }

  // Change the Fleep user name to the Bot name
  changeNick(callback) {
    return this.post('account/configure', {display_name: this.options.name}, (err, resp) => {
      this.robot.logger.debug(resp);
      this.robot.logger.debug('Nick changed');
      return callback();
    });
  }

  // Sync the list of known contacts
  syncContacts(callback) {
    return this.post('contact/sync/all', {ignore: []}, (err, resp) => {
      for (let contact of Array.from(resp.contacts)) { this.handleStreamEvent(contact); }
      this.robot.logger.debug('Contacts in sync');
      return callback();
    });
  }

  // Synchronizes some initial data with Fleep
  // list of conversations / bot nick / contacts / event_horizon
  sync() {

    this.robot.logger.debug("Syncing...");

    // Does synchronization operations in parallel
    // Calls the callback function only if all operations are complete
    return async.parallel([
      cb => this.populateConversationList(cb),
      cb => this.syncEventHorizon(cb),
      cb => this.changeNick(cb),
      cb => this.syncContacts(cb)
    ], (err, results) => {
      if (err !== null) {
        this.robot.logger.error(`Error during data sync: ${JSON.stringify(err)}`);
      }
      this.robot.logger.debug('Everything synced, ready to go!');
      return this.emit('synced', this);
    });
  }
});

function __guard__(value, transform) {
  return (typeof value !== 'undefined' && value !== null) ? transform(value) : undefined;
}