# Defines a simple chat server with separate services to handle user data
# and actual chatting.


mimic = require 'mimic'
uuid  = require('uuid').v4
express = require 'express'

# dummy async DB for demo purposes
class SimpleDb
  constructor: -> @data = {}
  get: (key, done) -> setTimeout( ->
    done(null, @data[key])
  , 50)

  set: (key, value, done) -> setTimeout( ->
    @data[key] = value
    done() if done
  , 50)
    
  del: (key, done) -> setTimeout( ->
    delete @data[key]
    done() if done
  , 50)
  
  list: (domain, done) -> setTimeout( ->
    ret = []
    for id, rec of @data
      ret.push rec if id.slice(0,domain.length) == domain
    done null, ret
  , 50)

# User Service!    
class UserService extends FiberService
  
  # simple in memory DB for fun...
  constructor: ->
    super
    db = new SimpleDb()

  @index (res, opts) ->
    res.send @future(@db.list("user", @resume)).wait()
      
  # gets a user instance from the DB
  @show (res, opts) ->
    user = @future(@db.get("user:#{opts.id}", @resume)).wait()
    if user then res.send(data: user)
    else res.send(mimic.NOT_FOUND) # HTTP codes
  
  # creates a new user instance
  @create (res, opts) ->
    user = opts.body
    user.id = uuid()
    @future(@db.set("user:#{user.id}", user, @resume)).wait()
    res.send(data: user)
  
  # deletes a user instance
  @del (res, opts) ->
    @db.del "user:#{opts.id}" # don't wait
    res.send(200)
    
  # update user
  @update (res, opts) ->
    userId = "user:#{opts.id}"
    user = @future(@db.get(userId, @resume)).wait()
    ['username', 'gender', 'age'].forEach (key) ->
      user[key] = opts[key] || user[key] # merge
    @future(@db.set(userId, user, @resume)).wait()
    res.send(data: user)
    

# Chat Service - let's you post with a userId and message body.
# notifies any listeners on the service.
class CoreChatService extends FiberService
  
  constructor: ->
    super
    @db = new SimpleDb()
    
  # called by other services to start listening for
  # notifications.
  @post "subscriptions", (res, opts) ->
    serviceId = opts.serviceId
    path      = opts.path
    @db.set("subscriptions:#{serviceId}", serviceId: serviceId, path: path)
    res.send 200 #OK!
    
  @del "subscriptions", (res, opts) ->
    @db.del("subscriptions:#{serviceId}")
    res.send 200 #OK!

  # send a message. takes a userId and a message. We verify
  # the user still exists, expand the name and then send to
  # all listeners.
  @post "messages", (res, opts) ->
    message = opts.body
    userId  = message.userId
    message.id = uuid()
    
    # throws exception on error
    message.user = @request('users').get(userId).wait()
    delete message.userId

    requests = []
    @future(@db.list("subscriptions", @resume)).wait().forEach (l) ->
      requests.push @request(l.serviceId).post(l.path, body: message)
    
    results = @wait(requests) # wait until they were all delivered...
    passed = results.filter (result) -> result.status != 200 
    res.send(if passed.length == 0 then 200 else 400) # something failed!


# Edge Node for the Chat Service. We create a new one for each incoming
# connection.
class EdgeChatService extends FiberService
  
  # this is the interface exposed to our connect service
  start: (fn) ->
    @fn
    req = @request('core_chat')
    req.post('subscriptions', serviceId: @id, path: 'notify')

  stop: ->
    req = @request('core_chat').del('subscriptions', serviceId: @id)
    
  # called from the CoreChatService
  @post 'notify', (res, opts) ->
    @fn opts.body # just notify our listener
    res.send 200
    
    
# Setup Mimic for core services
TIER = '*', # or 'core' or 'edge' or array - depending on server
intern = mimic
  tier: TIER, 
  tiers:
    core: 'http://core.myapp.com', 
    edge: 'http://core.myapp.com'
    
intern.add('core', 'users',     UserService)
      .add('core', 'core_chat', CoreChatService)

# listen on internal port
# this is only needed if we are really running multiple tiers
intern.createServer(host: 'localhost', port: 5050)
    

# Connect app. Just listens for HTTP request to do long polling.
app = express()
app.use app.routes

# here is how you send a message
app.post 'messages', (req, res) ->
  message = req.body
  # TODO: filter message - this is coming from the outside, we need to
  # make sure the data isn't bad!
  intern.request('core_chat').post('messages', body: message).done (err) ->
    res.send(if err then 400 else 200)

# long polling!
app.get 'messages', (req, res) ->
  
  # register a new edge service to listen for pushes.
  service = intern.add 'edge', intern.uuid(), EdgeChatService
  _cleanup ->
    service.stop()
    intern.remove 'edge', service.id
    
  req.on 'close', -> _cleanup # stop listening of client cancels
  
  # start listening
  service.start (message) ->
    _cleanup()
    res.send 200, message

# listen on public port


## Testing Core Chat Service
# This prevents you having to run the UserService DB.
class MockUserService extends Service
  
  @index  (res) -> res.send(body: [{ id: '1', username: 'okito' }])
  @create (res) -> res.send 201, id: '1'
  @show   (res, opts) -> res.send(body: { id: '1', username: 'okito' })
  @update (res, opts) -> res.send 200 # fake it
  @del (res, opts) -> res.send 200



describe 'posting a message', ->

  beforeEach ->
    intern = mimic().add
      users:      MockUserService
      core_chat:  CoreChatService
      edge1:      EdgeChatService
      
    # make edge listen and save posted message
    @message = null
    intern.services.edge1.start (message) => 
      @message = message

    
  it 'should return the user info embedded', ->
    mimic.request('core_chat')
      .post('messages', body: { userId: '1', message: 'foo' })
      .expect(200)
      .expect(body: { user: { id: '1', username: 'okito' }, message: 'foo' })
      .wait() # assuming you use mocha_fiber
    
  it 'should notify listening edges', ->
    mimic.request('core_chat')
      .post('message', body: { userId: '1', message: 'foo' })
      .wait()
      
    should.have @message
    @message.should.eql
      user: { id: '1', username: 'okito' }
      message: 'foo'
      
