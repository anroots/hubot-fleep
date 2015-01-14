#!/bin/bash

# The e-mail of your Fleep account
export HUBOT_FLEEP_EMAIL="ando@sqroot.eu"

# The password of your Fleep account
export HUBOT_FLEEP_PASSWORD="password"

# Specify the log level. Set to "debug" to enable debug mode.
export HUBOT_LOG_LEVEL="info"

# Mark the messages as 'seen' by the bot?
export HUBOT_FLEEP_MARK_SEEN=true

bin/hubot -a fleep -n BotName