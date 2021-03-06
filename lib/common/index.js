var debug;

debug = require('debug')('loopback:satellizer:common');

module.exports = function(options, provider) {
  var Model, authenticate, current, map;
  Model = options.model;
  authenticate = function(account, callback) {
    var ttl;
    ttl = 1000 * 60 * 60 * 24 * 7;
    return account.createAccessToken(ttl, function(err, token) {
      if (err) {
        return callback(err);
      }
      return Model.app.models.AccessToken.find({}, function(err, list) {
        token.token = token.id;
        return callback(null, token);
      });
    });
  };
  current = function(req, callback) {
    var AccessToken;
    debug('current');
    if (!req.headers.authorization) {
      return callback(null, false);
    }
    AccessToken = Model.app.models.AccessToken;
    return AccessToken.findForRequest(req, function(err, accessToken) {
      if (err) {
        Account.app.logger.error(err);
        return callback(err);
      }
      if (!accessToken) {
        return callback(null, false);
      }
      return Model.findById(accessToken.userId, callback);
    });
  };
  map = function(config, source, destination) {
    var key, results, value;
    results = [];
    for (key in config) {
      value = config[key];
      if (key in source) {
        results.push(destination[value] = destination[value] || source[key]);
      } else {
        results.push(void 0);
      }
    }
    return results;
  };
  return {
    authenticate: authenticate,
    current: current,
    map: map
  };
};
