
https = require 'https'

{EventEmitter} = require 'events'

Util = require './util'

module.exports = class WebRequest extends EventEmitter

  constructor: (@logger) ->
    super

  prepareReqOptions: (path, body, ticket, token_id) ->
    host = 'fleep.io'
    headers =
      Host: host
      'User-Agent': 'hubot-fleep'
  
    if token_id?
      cookie = 'token_id='+token_id
      @logger.debug "Setting cookie: #{cookie}"
      headers['Cookie'] = cookie
      
    reqOptions =
      agent: false
      hostname : host
      port     : 443
      path     : '/api/' + path
      method   : 'POST'
      headers  : headers
      
    if ticket?
      @logger.debug "Setting ticket: #{ticket}"
      body.ticket = ticket
        
    @logger.debug 'Request body:'
    @logger.debug body
        
    body = new Buffer JSON.stringify(body)
        
    reqOptions.headers['Content-Type'] = 'application/json'
    reqOptions.headers['Content-Length'] = body.length

    [reqOptions, body]


  post: (path, body, callback, ticket, token_id) ->
    @logger.debug 'Sending new POST request'

    [reqOptions, body] = this.prepareReqOptions path, body, ticket, token_id

    @logger.debug 'Request options:'
    @logger.debug reqOptions
    
    # Send the request
    request = https.request reqOptions, (response) =>

      @logger.debug 'Got response from the server.'
      data = ''
      response.on 'data', (chunk) ->
        data += chunk
  
      response.on 'end', =>
        if response.statusCode >= 400
          @logger.error "Fleep API error : #{response.statusCode}"
          @logger.error data
  
        @logger.debug 'Response headers:'
        @logger.debug response.headers
          
        data = JSON.parse data

        @logger.debug 'HTTPS response body:'
        @logger.debug data
          
        metaData = {}

        if response.headers['set-cookie']? and
        response.headers['set-cookie'][0]?
          token_id = this.getCookie response.headers['set-cookie'][0]
          @logger.debug 'Saving cookie value for later use: token_id='+token_id
          metaData['token_id'] = token_id
          
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

  

  getCookie: (header) ->
    @logger.debug 'Parsing cookie string ' + header
    parts = header.split ';'
    if parts[0]?
      parts = parts[0].split '='
      @logger.debug 'Token is ' + parts[1]
      parts[1]
