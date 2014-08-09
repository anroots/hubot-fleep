module.exports = class Util

  @log: console.log.bind console
  @logError: console.error.bind console
  
  @debug: (object) -> 
  	if @isDebug()
  	  @log object
  
  @isDebug: -> process.env.HUBOT_FLEEP_DEBUG is 'true' or false

  @parseOptions: ->
        email : process.env.HUBOT_FLEEP_EMAIL
        password : process.env.HUBOT_FLEEP_PASSWORD
        conversations : process.env.HUBOT_FLEEP_CONVERSATIONS?.split(',') or []
        name  : process.env.HUBOT_FLEEP_BOTNAME or 'FleepBot'
        debug : @isDebug()
