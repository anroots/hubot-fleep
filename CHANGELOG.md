# Changelog

## 0.9.1 - 2019-03-21

### Fixed

- Update `.reply` method to work with the new Fleep API spec

## 0.9.0 - 2019-03-20

### Changed

- Revert release `0.8.0` - it was not properly tested and turned out `decaffination`
  introduced bugs and changed JS behavior. Reverting until a proper migration can be done.

## 0.8.0 - 2019-03-17

### Changed

- Converted adapter from CoffeeScript to JavaScript (#16)

## 0.7.1 - 2015-08-02

### Added
- Implement backoff strategy for failed requests (retry Fleep API request if Fleep responds with HTTP 5XX)
- Add support for HTTPS proxy: exporting `https_proxy` environment variable should now have an effect to the HTTPS client

## 0.7.0 - 2015-02-21
- Add error handling to Fleep API response decoding
- Save users phone number to Redis

## 0.5.0 - 2015-01-26
- Remove support for automatic image uploads
- Improve error handling and documentation
- Use external libraries for common tasks

## 0.3.1 - 2015-01-08
- Fix an error with the @logger instance being unavailable.

## 0.3 - 2015-01-04

- https://github.com/anroots/hubot-fleep/pull/5

## 0.2.1 - 2015-01-03

- Add .travis.yml

## 0.2 - 2014-12-31

- Fix bug with editing Fleep messages

## 0.1.1 - 2014-12-31

- Fix bug with Util.logError call