module.exports = class Util

  @parseOptions: ->
    email : process.env.HUBOT_FLEEP_EMAIL
    password : process.env.HUBOT_FLEEP_PASSWORD
    markSeen : not process.env.HUBOT_FLEEP_MARK_SEEN? or
     process.env.HUBOT_FLEEP_MARK_SEEN is 'true'
