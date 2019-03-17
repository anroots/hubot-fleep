/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const {Robot, Adapter} = require('hubot');

const { EventEmitter } = require('events');
const Util = require('./util');
const FleepClient = require('./fleepClient');

class Fleep extends Adapter {

  // Adapter constructor
  constructor(robot) {

    // Call parent constructor
    super(robot);

    this.brainLoaded = false;

    // Parse environment options into a usable object
    this.options = Util.parseOptions();

    // Construct a new instance of FleepClient
    // The client will be the class doing most of the hard work of
    // passing requests to and from Fleep
    this.fleepClient = new FleepClient({
      name: this.robot.name,
      markSeen: this.options.markSeen
    }, this.robot);
  }


  // Send a message to the chat room where the envelope originated
  send(envelope, ...messages) {
    return Array.from(messages).map((message) => this.fleepClient.send(envelope, message));
  }

  // Send a 1:1 message (a private message) to the user who sent the envelope
  reply(envelope, ...messages) {
    return Array.from(messages).map((message) => this.fleepClient.reply(envelope, message));
  }

  // Change conversation topic
  topic(envelope, ...topics) {
    return this.fleepClient.topic(envelope.room, topics.join(' / '));
  }

  // Public: Dispatch a received message to the robot.
  receive(message) {
    return this.robot.receive(message);
  }

  run() {

    this.robot.logger.info('Starting Hubot with the Fleep.io adapter...');

    // Check that Fleep account details have been provided
    if (this.options.email == null) {
      this.robot.logger.emergency('You must specify HUBOT_FLEEP_EMAIL');
      process.exit(1);
    }
    if (this.options.password == null) {
      this.robot.logger.emergency('You must specify HUBOT_FLEEP_PASSWORD');
      process.exit(1);
    }

    // When FleepClient has authenticated against Fleep and is ready to continue
    // Do initial data sync between the Hubot and Fleep
    this.fleepClient.on('authenticated', client => client.sync());

    // When initial data sync (read messages, contacts etc) is done
    // Start long polling cycle
    this.fleepClient.on('synced', client => client.poll());

    // Got a message from Fleep
    this.fleepClient.on('gotMessage', message => {
      return this.receive(message);
    });

    // Only login to Fleep once the brain has loaded
    this.robot.brain.on('loaded', () => {

      // Do this only once
      if (this.brainLoaded) { return; }

      this.brainLoaded = true;

      this.robot.logger.debug('Robot brain connected.');
      this.robot.brain.setAutoSave(true);
      return this.fleepClient.login(this.options.email, this.options.password);
    });


    return this.emit('connected');
  }

  // Logout from Fleep when the session is closed
  close() {
    return this.fleepClient.logout();
  }
}

exports.use = robot => new Fleep(robot);
