dashdash       = require 'dashdash'
Redis          = require 'ioredis'
RedisNS        = require '@octoblu/redis-ns'
SigtermHandler = require 'sigterm-handler'
Worker         = require './src/worker'
Env            = require './src/env'

OPTIONS = [
  {
    names: ['help', 'h']
    type: 'bool'
    help: 'Print this help and exit.'
  },
  {
    names: ['version', 'v']
    type: 'bool'
    help: 'Print the version and exit.'
  }
]

class Command
  constructor: (@argv) ->
    process.on 'uncaughtException', @die
    @parser = dashdash.createParser({options: OPTIONS})
    @parseOptions()
    @env = new Env().get()

  printHelp: =>
    options = { includeEnv: true, includeDefaults:true }
    console.log "usage: queue-length-verifier [OPTIONS]\noptions:\n#{@parser.help(options)}"

  parseOptions: =>
    options = @parser.parse(@argv)
    if options.help
      @printHelp()
      process.exit 0
    if options.version
      console.log require('./package.json').version
      process.exit 0
    return options

  run: =>
    @getRedisClient (error, client) =>
      return @die error if error?

      worker = new Worker { client, @env }
      worker.run @die

      sigtermHandler = new SigtermHandler { events: ['SIGINT', 'SIGTERM'] }
      sigtermHandler.register worker.stop

  getRedisClient: (callback) =>
    redisClient = new Redis @env.REDIS_URI, dropBufferSupport: true
    client      = new RedisNS @env.NAMESPACE, redisClient
    client.ping (error) =>
      return callback error if error?
      client.once 'error', @die
      callback null, client

  die: (error) =>
    return process.exit(0) unless error?
    console.error 'ERROR'
    console.error error.stack
    process.exit 1

module.exports = Command
