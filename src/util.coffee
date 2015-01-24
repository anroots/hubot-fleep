
module.exports = class Util

  # Merge input objects into one object
  @merge: (xs...) ->
    tap = (o, fn) -> fn(o); o
    if xs?.length > 0
      tap {}, (m) -> m[k] = v for k, v of x for x in xs

  @parseOptions: ->

    getOpt = (name, defaultValue) ->
      return defaultValue unless process.env['HUBOT_FLEEP_' + name]?
      return process.env['HUBOT_FLEEP_' + name]

    email : getOpt 'EMAIL'
    password : getOpt 'PASSWORD'
    markSeen : getOpt('MARK_SEEN', 'true') is 'true'

