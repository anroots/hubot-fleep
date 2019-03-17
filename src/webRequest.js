/*
 * decaffeinate suggestions:
 * DS001: Remove Babel/TypeScript constructor workaround
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
let WebRequest;
const https = require('https');
const url = require('url');
const cookie = require('cookie');
const proxy = require('proxy-agent');
const backoff = require('backoff');

const {EventEmitter} = require('events');

const Util = require('./util');

module.exports = (WebRequest = class WebRequest extends EventEmitter {

  constructor(logger, ticket, token_id) {

    // Init Backoff object, which will be used to do exponential backoff
    // when the request fails
    {
      // Hack: trick Babel/TypeScript into allowing this before super.
      if (false) { super(); }
      let thisFn = (() => { return this; }).toString();
      let thisName = thisFn.match(/return (?:_assertThisInitialized\()*(\w+)\)*;/)[1];
      eval(`${thisName} = this;`);
    }
    this.logger = logger;
    this.ticket = ticket;
    this.token_id = token_id;
    this.fibonacciBackoff = backoff.fibonacci({
      initialDelay: 10,
      maxDelay: 300
    });
    this.fibonacciBackoff.failAfter(10);

    super(...arguments);
  }

  prepareReqOptions(path, body, headers) {

    if (body == null) { body = {}; }
    if (headers == null) { headers = {}; }
    const host = 'fleep.io';

    headers = Util.merge({
      Host: host,
      'User-Agent': 'hubot-fleep/0.7.0',
      'Content-Type': 'application/json'
    }, headers);

    if (this.token_id != null) {
      const cookieString = cookie.serialize('token_id', this.token_id);
      this.logger.debug(`Setting cookie: ${cookieString}`);
      headers['Cookie'] = cookieString;
    }

    const { https_proxy } = process.env;
    const agent = (https_proxy != null) ? new proxy(https_proxy) : false;
    const reqOptions = {
      agent,
      hostname : host,
      port     : 443,
      path     : `/api/${path}`,
      method   : 'POST',
      headers
    };

    if (this.ticket != null) {
      this.logger.debug(`Setting ticket: ${this.ticket}`);
      body.ticket = this.ticket;
    }

    // Encode JSON request body into a string format.
    // Only do this if it's not a file upload request
    if (headers['Content-Disposition'] == null) {
      body = new Buffer(JSON.stringify(body));
    }

    reqOptions.headers['Content-Length'] = body.length;

    return [reqOptions, body];
  }

  post(path, jsonBody, callback, headers) {
    if (headers == null) { headers = {}; }
    this.logger.debug('Sending new POST request');

    const [reqOptions, body] = Array.from(this.prepareReqOptions(path, jsonBody, headers));

    this.logger.debug(`Request options: ${JSON.stringify(reqOptions)}`);
    this.logger.debug(`Request body: ${JSON.stringify(jsonBody)}`);

    // Send the request
    const request = https.request(reqOptions, response => {

      this.logger.debug('Response headers: ' +
        JSON.stringify(response.headers, null, 2)
      );

      // Get the response stream into a variable
      let data = '';
      response.on('data', chunk => data += chunk);

      return response.on('end', () => {


        // Handle HTTP response errors from the Fleep API
        let error;
        if (response.statusCode >= 400) {
          this.logger.error(`Fleep API error, HTTP status is ${response.statusCode}`);
          this.logger.error(`Raw response body: ${data}`);

          // Call the callback with error data and return on HTTP 4XX errors
          if ((response.statusCode >= 400) && (response.statusCode < 500)) {
            if (typeof callback === 'function') {
              callback(data);
            }
            return;
          }

          // Emitted when a backoff operation is started
          this.fibonacciBackoff.on('backoff', (number, delay) => {
            return this.logger.error(`Request failed, retry in ${delay} seconds`);
          });

          // Emitted when a backoff operation is done
          this.fibonacciBackoff.on('ready', (number, delay) => {
            this.logger.info('Resending the request');
            return this.post(path, jsonBody, callback, headers);
          });

          // Emitted when the maximum number of backoffs is reached
          this.fibonacciBackoff.on('fail', function(number, delay) {
            return this.logger.error('Max number of backoff requests reached');
          });

          this.fibonacciBackoff.backoff();

          return;
        }

        // Parse Fleep API response into a JSON structure
        try {
          data = JSON.parse(data);
          this.logger.debug(`Response body: ${JSON.stringify(data, null, 2)}`);
        } catch (error1) {
          error = error1;
          this.logger.error('Error when trying to decode the response as JSON');
          this.logger.error(`Raw response body: ${data}`);
          if (typeof callback === 'function') {
            callback(data);
          }
          return;
        }

        const metaData = {};

        if ((response.headers['set-cookie'] != null) &&
        (response.headers['set-cookie'][0] != null)) {
          this.token_id = this.getToken(response.headers['set-cookie'][0]);
          this.logger.debug(`Saving cookie value for later use: token_id=${this.token_id}`);
          metaData['token_id'] = this.token_id;
        }

        // Reset backoff object
        this.fibonacciBackoff.reset();

        this.logger.debug(`Calling callback of request ${reqOptions.path}`);
        if (typeof callback === 'function') {
          callback(null, data, metaData);
        }

        return response.on('error', function(err) {
          this.logger.error('HTTPS response error:', err);
          return (typeof callback === 'function' ? callback(err, null) : undefined);
        });
      });
    });

    request.end(body, 'binary');

    return request.on('error', err => {
      this.logger.error('HTTPS request error:', err);
      this.logger.error(err.stack);
      return (typeof callback === 'function' ? callback(err) : undefined);
    });
  }

  getToken(cookieString) {
    this.logger.debug(`Parsing cookie string ${cookieString}`);
    const cookies = cookie.parse(cookieString);
    this.logger.debug(`Token is ${cookies.token_id}`);
    return cookies.token_id;
  }
});
