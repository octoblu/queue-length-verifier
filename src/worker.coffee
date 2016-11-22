_       = require 'lodash'
async   = require 'async'
moment  = require 'moment'
request = require 'request'

class Worker
  constructor: (options={})->
    { @client, @env, @currentTime, @consoleError, @consoleLog } = options
    throw new Error('Worker: requires client') unless @client?
    throw new Error('Worker: requires env') unless @env?
    @consoleLog ?= console.log
    @consoleError ?= console.error

  do: (callback) =>
    @client.llen @env.QUEUE_NAME, (error, count) =>
      return callback error if error?
      count = _.parseInt count
      if count < @env.QUEUE_MAX_LENGTH
        @report { success: true }, callback
        return
      error = new Error "Queue length exceeded max #{count} >= #{@env.QUEUE_MAX_LENGTH}"
      @report { success: false, error }, callback
    return # avoid returning promise

  report: ({ success, error }, callback) =>
    currentDate = moment()
    currentDate = moment.unix(@currentTime) if @currentTime
    expires = currentDate.add(@env.LOG_EXPIRATION, 'seconds').valueOf()
    options = {
      url: @env.LOG_URL,
      json: { success, expires }
    }
    _.set options, 'json.error.message', error?.message if error?.message?
    request.post options, (httpError, response) =>
      error ?= httpError
      @print error
      callback()

  print: (error) =>
    return @consoleLog 'queue-length ok' unless error?
    @consoleError 'queue-length failure', error.toString()

  doAndDelay: (callback) =>
    @do (error) =>
      return callback error if error?
      _.delay callback, @env.CHECK_DELAY

  run: (callback) =>
    async.doUntil @doAndDelay, @shouldStop, (error) =>
      return @stopCallback error if @stopCallback?
      callback error

  shouldStop: =>
    return @_shouldStop

  stop: (@stopCallback) =>
    @_shouldStop = true

module.exports = Worker
