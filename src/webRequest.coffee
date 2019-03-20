https = require 'https'
url = require 'url'
cookie = require 'cookie'
proxy = require 'proxy-agent'
backoff = require 'backoff'

{EventEmitter} = require 'events'

Util = require './util'

module.exports = class WebRequest extends EventEmitter

  constructor: (@logger, @ticket, @token_id) ->

    # Init Backoff object, which will be used to do exponential backoff
    # when the request fails
    @fibonacciBackoff = backoff.fibonacci {
      initialDelay: 10,
      maxDelay: 300
    }
    @fibonacciBackoff.failAfter 10

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

    https_proxy = process.env.https_proxy
    agent = if https_proxy? then new proxy https_proxy else false
    reqOptions =
      agent: agent
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

  post: (path, jsonBody, callback, headers = {}) ->
    @logger.debug 'Sending new POST request'

    [reqOptions, body] = this.prepareReqOptions path, jsonBody, headers

    @logger.debug 'Request options: ' + JSON.stringify reqOptions
    @logger.debug 'Request body: ' + JSON.stringify jsonBody

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
          @logger.error "Fleep API error, HTTP status is #{response.statusCode}"
          @logger.error 'Raw response body: ' + data

          # Call the callback with error data and return on HTTP 4XX errors
          if response.statusCode >= 400 and response.statusCode < 500
            callback? data
            return

          # Emitted when a backoff operation is started
          @fibonacciBackoff.on 'backoff', (number, delay) =>
            @logger.error "Request failed, retry in #{delay} seconds"

          # Emitted when a backoff operation is done
          @fibonacciBackoff.on 'ready', (number, delay) =>
            @logger.info 'Resending the request'
            @post path, jsonBody, callback, headers

          # Emitted when the maximum number of backoffs is reached
          @fibonacciBackoff.on 'fail', (number, delay) ->
            @logger.error 'Max number of backoff requests reached'

          @fibonacciBackoff.backoff()

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

        # Reset backoff object
        @fibonacciBackoff.reset()

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
