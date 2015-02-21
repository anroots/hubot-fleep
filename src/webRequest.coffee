
https = require 'https'
url = require 'url'
cookie = require 'cookie'

{EventEmitter} = require 'events'

Util = require './util'

module.exports = class WebRequest extends EventEmitter

  constructor: (@logger, @ticket, @token_id) ->
    super

  prepareReqOptions: (path, body = {}, headers = {}) ->

    host = 'fleep.io'

    headers = Util.merge {
      Host: host
      'User-Agent': 'hubot-fleep/0.7.0',
      'Content-Type': 'application/json'
    }, headers

    if @token_id?
      cookieString = cookie.serialize 'token_id', @token_id
      @logger.debug "Setting cookie: #{cookieString}"
      headers['Cookie'] = cookieString

    reqOptions =
      agent: false
      hostname : host
      port     : 443
      path     : '/api/' + path
      method   : 'POST'
      headers  : headers

    if @ticket?
      @logger.debug "Setting ticket: #{@ticket}"
      body.ticket = @ticket

    # Encode JSON request body into a string format.
    # Only do this if it's not a file upload request
    unless headers['Content-Disposition']?
      body = new Buffer JSON.stringify(body)

    reqOptions.headers['Content-Length'] = body.length

    [reqOptions, body]

  post: (path, body, callback, headers = {}) ->
    @logger.debug 'Sending new POST request'

    [reqOptions, body] = this.prepareReqOptions path, body, headers

    @logger.debug 'Request options:'
    @logger.debug reqOptions

    # Send the request
    request = https.request reqOptions, (response) =>

      @logger.debug 'Response headers: ' +
        JSON.stringify response.headers, null, 2

      # Get the response stream into a variable
      data = ''
      response.on 'data', (chunk) ->
        data += chunk

      response.on 'end', =>


        # Handle HTTP response errors from the Fleep API
        if response.statusCode >= 400
          @logger.error "Fleep API error : #{response.statusCode}"
          @logger.error 'Raw response body: ' + data
          callback? data
          return

        # Parse Fleep API response into a JSON structure
        try
          data = JSON.parse data
          @logger.debug 'Response body: ' + JSON.stringify data, null, 2
        catch error
          @logger.error 'Error when trying to decode the response as JSON'
          @logger.error 'Raw response body: ' + data
          callback? data
          return

        metaData = {}

        if response.headers['set-cookie']? and
        response.headers['set-cookie'][0]?
          @token_id = @getToken response.headers['set-cookie'][0]
          @logger.debug 'Saving cookie value for later use: token_id='+@token_id
          metaData['token_id'] = @token_id

        @logger.debug 'Calling callback of request '+reqOptions.path
        callback? null, data, metaData

        response.on 'error', (err) ->
          @logger.error 'HTTPS response error:', err
          callback? err, null

    request.end body, 'binary'

    request.on 'error', (err) =>
      @logger.error 'HTTPS request error:', err
      @logger.error err.stack
      callback? err

  getToken: (cookieString) ->
    @logger.debug 'Parsing cookie string ' + cookieString
    cookies = cookie.parse cookieString
    @logger.debug 'Token is ' + cookies.token_id
    cookies.token_id
