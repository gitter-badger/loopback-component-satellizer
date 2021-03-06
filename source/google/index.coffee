async         = require 'async'
debug         = require('debug') 'loopback:satellizer:google'
request       = require 'request'
randomstring  = require 'randomstring'

common = require '../common'

module.exports = (options) ->

  Common      = common options
  Model       = options.model

  credentials = options.google.credentials

  fetchAccessToken = (code, clientId, redirectUri, callback) ->
    debug 'fetchAccessToken'
    request.post
      url: 'https://accounts.google.com/o/oauth2/token'
      form:
        code: code
        client_id: clientId
        client_secret: credentials.private
        redirect_uri: redirectUri
        grant_type: 'authorization_code'
      json: true
    , (err, res, token) ->
      return callback err if err
      callback null, token.access_token

  fetchProfile = (accessToken, callback) ->
    debug 'fetchProfile'
    request.post
      url: 'https://www.googleapis.com/plus/v1/people/me/openIdConnect'
      headers:
        Authorization: "Bearer: #{accessToken}"
      json: true
    , (err, res, profile) ->
      return callback err if err
      callback null, profile

  link = (req, profile, callback) ->
    debug 'link'
    Common.current req, (err, found) ->
      if err
        debug err
        return callback err
      if found is null
        err = new Error 'not_an_account'
        err.status = 409
        debug err
        return callback err
      if found
        return link.existing profile, found, callback
      #
      query =
        where: {}
      query.where[options.google.mapping.id] = profile.email
      #
      Model.findOne query, (err, found) ->
        if err
          debug err
          return callback err
        return link.create profile, callback if not found
        return link.existing profile, found, callback

  link.create = (profile, callback) ->
    debug 'link.create', profile.id
    tmp =
      password: randomstring.generate()
    Common.map options.google.mapping, profile, tmp
    Model.create tmp, (err, created) ->
      debug err if err
      return callback err, created

  link.existing = (profile, account, callback) ->
    debug 'link.existing'
    if account.google and account[options.google.mapping.id] != profile.id
      err = new Error 'account_conflict'
      err.status = 409
      debug err
      return callback err
    Common.map options.google.mapping, profile, account
    account.save (err) ->
      debug err if err
      return callback err, account

  Model.google = (req, code, clientId, redirectUri, callback) ->
    debug "#{code}, #{clientId}, #{redirectUri}"
    async.waterfall [
      (done) ->
        fetchAccessToken code, clientId, redirectUri, done
      (accessToken, done) ->
        fetchProfile accessToken, done
      (profile, done) ->
        link req, profile, done
      (account, done) ->
        Common.authenticate account, done
    ], callback

  Model.remoteMethod 'google',
    accepts: [
      {
        arg: 'req'
        type: 'object'
        http:
          source: 'req'
      }
      {
        arg: 'code'
        type: 'string'
        http:
          source: 'form'
      }
      {
        arg: 'clientId'
        type: 'string'
        http:
          source: 'form'
      }
      {
        arg: 'redirectUri'
        type: 'string'
        http:
          source: 'form'
      }
    ]
    returns:
      arg: 'result'
      type: 'object'
      root: true
    http:
      verb: 'post'
      path: options.google.uri

  return
