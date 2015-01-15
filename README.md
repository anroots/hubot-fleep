# hubot-fleep

[Hubot](https://github.com/github/hubot) adapter for [Fleep.io](http://fleep.io).
Enables to add a Hubot bot to Fleep.io conversations.

[![Build Status](https://img.shields.io/travis/anroots/hubot-fleep.svg)](https://travis-ci.org/anroots/hubot-fleep)
[![Downloads](https://img.shields.io/npm/dm/hubot-fleep.svg)](https://www.npmjs.com/package/hubot-fleep)
[![Version](https://img.shields.io/npm/v/hubot-fleep.svg)](https://github.com/anroots/hubot-fleep/releases)
[![Licence](https://img.shields.io/npm/l/express.svg)](https://github.com/anroots/hubot-fleep/blob/master/LICENSE)

The adapter is in alpha status: it works for straightforward usage, but contains yet-to-be-discovered bugs. See the Issues tab for a list of known bugs and create a new issue if you discover something new.

# Installation

* Follow the "[Getting Started With Hubot](https://github.com/github/hubot/blob/master/docs/README.md)" guide to get a local installation of Hubot
* When `yo hubot` command asks for an adapter, enter "fleep"
* Create a new Fleep account for Hubot
* Copy the `start.sh` script (from `node_modules/hubot-fleep` to hubot root dir), edit it and fill in Fleep user credentials
* Start hubot by running `./start.sh`
* Add the Hubot Fleep user to any conversation in Fleep

## Environment variables

The adapter requires the following environment variables to be defined:

* `HUBOT_FLEEP_EMAIL` _string, default: none_ - The e-mail of your Fleep account for the Hubot instance
* `HUBOT_FLEEP_PASSWORD` _string, default: none_ - The password of your Fleep account

In addition, the following optional variables can be set:

* `HUBOT_LOG_LEVEL` _string [debug|info|notice|warning|error|critical|alert|emergency], default: info_ - Set the log level of Hubot. The Fleep adapter can output extensive debug messages.
* `HUBOT_FLEEP_MARK_SEEN` _bool, default: true_ - Whether to mark Fleep messages as 'seen' by the bot. Enabling this gives users additional information about the bot's responsiveness, but forces the bot to make an additional HTTP request
* `HUBOT_FLEEP_UPLOAD_IMAGES` _bool, default: true_ - Whether to upload image URL-s automatically to Fleep as image attachments

# Contributing

You can contribute to the development of this adapter by sending pull requests and by reporting issues.

# Licence

The MIT License (MIT). Please see LICENCE file for more information.