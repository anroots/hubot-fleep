
https = require 'https'

{EventEmitter} = require 'events'

Util = require './util'

module.exports = class WebRequest extends EventEmitter

  @prepareReqOptions: (path, body, ticket, token_id) ->
    host = 'fleep.io'
    headers =
      Host: host
      'User-Agent': 'hubot-fleep'
  
    if token_id?
      cookie = 'token_id='+token_id
      Util.debug "Setting cookie: #{cookie}"
      headers['Cookie'] = cookie
      
    reqOptions =
      agent: false
      hostname : host
      port     : 443
      path     : '/api/' + path
      method   : 'POST'
      headers  : headers
      
    if ticket?
      Util.debug "Setting ticket: #{ticket}"
      body.ticket = ticket
        
    Util.debug 'Request body:'
    Util.debug body
        
    body = new Buffer JSON.stringify(body)
        
    reqOptions.headers['Content-Type'] = 'application/json'
    reqOptions.headers['Content-Length'] = body.length

    [reqOptions, body]


  @request: (path, body, callback, ticket, token_id) ->
    Util.debug 'Sending new POST request'

    [reqOptions, body] = @prepareReqOptions path, body, ticket, token_id

    Util.debug 'Request options:'
    Util.debug reqOptions
    
    # Send the request  
    request = https.request reqOptions, (response) =>

      Util.debug 'Got response from the server.'
      data = ''
      response.on 'data', (chunk) ->
        data += chunk
  
      response.on 'end', =>
        if response.statusCode >= 400
          Util.logerror "Fleep API error : #{response.statusCode}"
          Util.logerror data
  
        Util.debug 'Response headers:'
        Util.debug response.headers
          
        data = JSON.parse data

        Util.debug 'HTTPS response body:'
        Util.debug data
          
        metaData = {}

        if response.headers['set-cookie']? and response.headers['set-cookie'][0]?
          token_id = @getCookie response.headers['set-cookie'][0]
          Util.debug 'Saving cookie value for later use: token_id='+token_id
          metaData['token_id'] = token_id
          
        Util.debug 'Calling callback of request '+reqOptions.path
        callback? null, data, metaData
  
        response.on 'error', (err) ->
          Util.logerror 'HTTPS response error:', err
          callback? err, null
  
    request.end body, 'binary'
  
    request.on 'error', (err) ->
      Util.logerror 'HTTPS request error:', err
      Util.logerror err.stack
      callback? err

  

  @getCookie: (header) ->
    Util.debug 'Parsing cookie string ' + header
    parts = header.split ';'
    if parts[0]?
      parts = parts[0].split '='
      Util.debug 'Token is ' + parts[1]
      parts[1]
