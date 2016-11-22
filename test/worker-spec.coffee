async         = require 'async'
UUID          = require 'uuid'
shmock        = require 'shmock'
moment        = require 'moment'
Redis         = require 'ioredis'
RedisNS       = require '@octoblu/redis-ns'
enableDestroy = require 'server-destroy'
Worker        = require '../src/worker'
Env           = require '../src/env'

describe 'QueueLengthWorker', ->
  beforeEach (done) ->
    @env = new Env({
      REDIS_URI: 'localhost'
      NAMESPACE: "test-worker-#{UUID.v1()}"
      QUEUE_NAME: 'some-queue'
      QUEUE_MAX_LENGTH: 10
      LOG_URL: "http://some-user:some-pass@localhost:#{0xd00d}/verifications/test"
    }).get()
    redisClient = new Redis @env.REDIS_URI, dropBufferSupport: true
    @client     = new RedisNS @env.NAMESPACE, redisClient
    @client.ping (error) =>
      @client.once 'error', done
      done error
    return # dumb redis promise fix

  beforeEach ->
    @verifierService = shmock 0xd00d
    enableDestroy @verifierService
    @currentTime = moment().unix()
    @consoleLog = sinon.spy()
    @consoleError = sinon.spy()
    @sut = new Worker { @client, @env, @currentTime, @consoleLog, @consoleError }

  afterEach ->
    @verifierService.destroy()

  describe 'when the queue length is greater than the max', ->
    beforeEach (done) ->
      async.times 12, (n, next) =>
        data = JSON.stringify { foo: 'bar', n }
        @client.lpush @env.QUEUE_NAME, data, next
        return # dumb redis promise fix
      , done

    beforeEach (done) ->
      auth = new Buffer('some-user:some-pass').toString('base64')
      expectedExpires = moment.unix(@currentTime).add(@env.LOG_EXPIRATION, 'seconds').valueOf()
      @verifyFailure = @verifierService
        .post '/verifications/test'
        .set 'Authorization', "Basic #{auth}"
        .send {
          success: false
          expires: expectedExpires
          error: { message: 'Queue length exceeded max 12 >= 10' }
        }
        .reply 201

      @sut.do (error) =>
        done error

    it 'should send a failure to the verifications endpoint', ->
      @verifyFailure.done()

    it 'should console.error failure', ->
      expect(@consoleError).to.have.been.calledWith 'queue-length failure', 'Error: Queue length exceeded max 12 >= 10'

  describe 'when the queue length is equal to the max', ->
    beforeEach (done) ->
      async.times 10, (n, next) =>
        data = JSON.stringify { foo: 'bar', n }
        @client.lpush @env.QUEUE_NAME, data, next
        return # dumb redis promise fix
      , done

    beforeEach (done) ->
      auth = new Buffer('some-user:some-pass').toString('base64')
      expectedExpires = moment.unix(@currentTime).add(@env.LOG_EXPIRATION, 'seconds').valueOf()
      @verifyFailure = @verifierService
        .post '/verifications/test'
        .set 'Authorization', "Basic #{auth}"
        .send {
          success: false
          expires: expectedExpires
          error: { message: 'Queue length exceeded max 10 >= 10' }
        }
        .reply 201

      @sut.do (error) =>
        done error

    it 'should send a failure to the verifications endpoint', ->
      @verifyFailure.done()

    it 'should console.error failure', ->
      expect(@consoleError).to.have.been.calledWith 'queue-length failure', 'Error: Queue length exceeded max 10 >= 10'

  describe 'when the queue length is less than the max', ->
    beforeEach (done) ->
      async.times 9, (n, next) =>
        data = JSON.stringify { foo: 'bar', n }
        @client.lpush @env.QUEUE_NAME, data, next
        return # dumb redis promise fix
      , done

    beforeEach (done) ->
      auth = new Buffer('some-user:some-pass').toString('base64')
      expectedExpires = moment.unix(@currentTime).add(@env.LOG_EXPIRATION, 'seconds').valueOf()
      @verifyFailure = @verifierService
        .post '/verifications/test'
        .set 'Authorization', "Basic #{auth}"
        .send {
          success: true
          expires: expectedExpires
        }
        .reply 201

      @sut.do (error) =>
        done error

    it 'should send a failure to the verifications endpoint', ->
      @verifyFailure.done()

    it 'should console.log ok', ->
      expect(@consoleLog).to.have.been.calledWith 'queue-length ok'

  describe 'when the queue length is zero', ->
    beforeEach (done) ->
      auth = new Buffer('some-user:some-pass').toString('base64')
      expectedExpires = moment.unix(@currentTime).add(@env.LOG_EXPIRATION, 'seconds').valueOf()
      @verifyFailure = @verifierService
        .post '/verifications/test'
        .set 'Authorization', "Basic #{auth}"
        .send {
          success: true
          expires: expectedExpires
        }
        .reply 201

      @sut.do (error) =>
        done error

    it 'should send a failure to the verifications endpoint', ->
      @verifyFailure.done()

    it 'should console.log ok', ->
      expect(@consoleLog).to.have.been.calledWith 'queue-length ok'
