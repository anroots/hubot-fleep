/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */

let Util;
module.exports = (Util = class Util {

  // Merge input objects into one object
  static merge(...xs) {
    const tap = function(o, fn) { fn(o); return o; };
    if ((xs != null ? xs.length : undefined) > 0) {
      return tap({}, m => Array.from(xs).map((x) => (() => {
        const result = [];
        for (let k in x) {
          const v = x[k];
          result.push(m[k] = v);
        }
        return result;
      })()) );
    }
  }

  // Return an object of adapter options
  static parseOptions() {

    // Extract option value from env constant or return the default value
    const getOpt = function(name, defaultValue) {
      if (process.env[`HUBOT_FLEEP_${name}`] == null) { return defaultValue; }
      return process.env[`HUBOT_FLEEP_${name}`];
    };

    return {
      email : getOpt('EMAIL'),
      password : getOpt('PASSWORD'),
      markSeen : getOpt('MARK_SEEN', 'true') === 'true'
    };
  }
});

