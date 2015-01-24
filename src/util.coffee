http = require 'http'
url = require 'url'

module.exports = class Util

  # Calls the callback function with a boolean argument
  # to indicate whether the uri is an image
  @isImageUri: (uri, callback) ->

    # Parse URI into components for a HEAD request
    urlParts = url.parse uri, true

    # Does not begin with https?://, return false immediately
    if urlParts.protocol is null
      callback false
      return

    # Determine the port to use
    port = urlParts.port
    if port is null
      port = if urlParts.protocol is 'http' then 80 else 443

    options =
      method: 'HEAD',
      host: urlParts.host,
      port: if urlParts.port isnt null then urlParts.port else 80,
      path: urlParts.path

    # Create a HEAD request to the uri
    request = http.request options, (response) ->

      imageTypes = ['image/gif','image/jpeg','image/png','image/svg+xml']

      # The URI is an image if it's
      # a) found and
      # b) it's content type is of that of an image
      isImage = response.statusCode is 200 and
          response.headers['content-type'] in imageTypes
      callback isImage
    request.end()

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
    uploadImages : getOpt('UPLOAD_IMAGES', 'true') is 'true'


