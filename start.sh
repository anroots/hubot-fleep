#!/bin/bash

# The e-mail of your Fleep account
export HUBOT_FLEEP_EMAIL="ando@sqroot.eu"

# The password of your Fleep account
export HUBOT_FLEEP_PASSWORD="password"

# List of initially monitored conversations (comma separated conversation IDs)
export HUBOT_FLEEP_CONVERSATIONS=""

# Enable debug mode
export HUBOT_FLEEP_DEBUG="true"

bin/hubot -a fleep