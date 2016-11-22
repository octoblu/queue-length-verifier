envalid           = require 'envalid'
{ str, num, url } = envalid

class Env
  constructor: (@processEnv) ->
    @processEnv ?= process.env

  get: =>
    return envalid.cleanEnv @processEnv, {
      REDIS_URI: str({ devDefault: 'redis://localhost:6379' })
      NAMESPACE: str()
      QUEUE_NAME: str()
      QUEUE_MAX_LENGTH: num({ default: 100 })
      CHECK_DELAY: num({ default: 1000 })
      LOG_URL: url()
      LOG_EXPIRATION: num({ default: 300 })
    }

module.exports = Env
