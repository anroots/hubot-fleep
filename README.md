# hubot-fleep

[Hubot](https://github.com/github/hubot) adapter for [Fleep.io](http://fleep.io).

# Installation

* Follow the "[Getting Started With Hubot](https://github.com/github/hubot/blob/master/docs/README.md)" guide to get a local installation of Hubot
* When `yo hubot` command asks for an adapter, enter "fleep"
* Copy the `start.sh` script and change the values
* Start hubot by running `./start.sh`

# Project status

The adapter works, but only for really straightforward usage. A lot of corner cases are as of yet unhandled: what happens when the bot joins with a conversation with previous history? What happens if the bot is present in multiple channels? What happens...

Feel free to build upon it (send pull requests!) and use it, but please, don't do it in production.
