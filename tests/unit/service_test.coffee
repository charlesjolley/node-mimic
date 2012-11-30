
########################################################
## DUMMY SERVICE
##

class MyService extends mimic.Service

  ## API
  @get 'greeting',
    description: 'Returns a greeting with an optional name'
    additionalProperties: no
    properties:
      name: { type: 'string', required: no }
      number: { type: 'number', required: no }
      
  @get 'fr-greeting',
    description: 'Returns a greeting in french'
    additionalProperties: no
    properties:
      name: { type: 'string', required: no }
      
  @del 'greeting',
    description: 'Returns a goodbye with optional name'
    additionalProperties: no
    properties:
      name: { type: 'string', required: no }
       
  ## HANDLERS 
  onGetGreeting: (res, opts) -> 
    res.send(body: "Hello #{opts.name || (opts.number + 23) || 'World'}")

  onGetFrGreeting: (res, opts) ->
    res.send(body: "Bonjour #{opts.name || 'Le Monde'}")
    
  onDeleteGreeting: (res, opts) -> 
    res.send(body: "Goodbye #{opts.name || 'World'}")
    
  # Added to try to trip up inheritence.
  onNamedGreeting: ->


########################################################
## TESTS
##

describe "instantiation", ->

  mimic = ()-> # fakeit

  it 'should save standard options on service', ->
    service = new MyService(app: mimic, id: 'service', tier: 'default')
    service.should.include.keys 'app', 'id', 'tier', 'href'
    service.app.should.eql  mimic
    service.id.should.eql   'service'
    service.tier.should.eql 'default'
    service.href.should.eql 'mimic:service.default'
      
  it 'should throw exception if no mimic', ->
    expect(-> new MyService(id: 'service', tier: 'default')).to.throw Error
    
  it 'should generate an ID and have default tier if none provided', ->
    service = new MyService(app: mimic)

    # make sure the generated ID is still valid for URLs
    expect(service.id).to.not.be.empty
      .and.to.not.contain('.')
      .and.to.not.contain(':')
      
    expect(service.tier).to.eql 'default'
    expect(service.href).to.eql("mimic:#{service.id}.default")
      
      
describe 'Service.route', ->

  class ChildService extends MyService
    
    @get 'fr-greeting/:name', method: 'onNamedGreeting',
      additionalProperties: no
      properties:
        name: { type: 'string', required: yes }

    onGreeting:      (res, opts) -> # new fn
    onNamedGreeting: (res, opts) ->

  beforeEach ->
    @service = new MyService(app: mimic, id: 'service', tier: 'default')
    @child   = new ChildService(app: mimic, id: 'child', tier: 'default')
  
  it 'should return a method for defined route', ->
    paths = ['greeting', '/greeting', 'GREETING', '/GREETING',
              '/Greeting/', '/GREETING/./', 'NOT/../greeting']
    
    paths.forEach (path) =>
      route = @service.route('get', path)
      expect(route, "get #{path}").not.to.be.null
      expect(route.fn, 'get fn').to.equal 'onGetGreeting'

      route = @service.route('delete', path)
      expect(route, "delete #{path}").not.to.be.null
      expect(route.fn, 'delete fn').to.eql 'onDeleteGreeting'
      
  it 'should map to non-default route names', ->
    route = @child.route('get', 'fr-greeting/:name')
    expect(route).not.to.be.null
    expect(route.fn, 'child fn').to.eql 'onNamedGreeting'
    
  it 'should handle inheritance overrides', ->
    expect(@service.route('get', 'greeting').fn, 'service.get')
      .to.equal 'onGetGreeting'
      
    expect(@child.route('get', 'greeting').fn, 'child.get')
      .to.equal 'onGetGreeting'


  it 'should add new handler on child and not to parent', ->
    expect(@service.route('get', 'fr-greeting/:name'), 'parent').to.be.null
    
  it 'should handle wildcards', ->
    plainRoute = @child.route 'get', 'fr-greeting'
    wildRoute  = @child.route 'get', 'fr-greeting/charles'
    
    expect(plainRoute, 'no wildcard').not.to.be.null
    expect(plainRoute.fn, 'no wildcard fn').to.equal 'onGetFrGreeting'
    
    expect(wildRoute, 'wildcard').not.to.be.null
    expect(wildRoute.fn, 'wildcard fn').to.equal 'onNamedGreeting'
    expect(wildRoute.params, 'wildcard params')
      .to.have.property 'name', 'charles'

describe 'Service.call()', ->
  
  beforeEach ->
    @service = new MyService(app: mimic, id: 'service', tier: 'default')
    
  it 'should return null for unknown paths', ->
    expect(@service.call 'get', 'not-a-path').to.equal null
  
  it 'should return null for mismatched verb', ->
    expect(@service.call 'put', 'greeting').to.equal null
    
  it 'should return a Response for known path', ->
    expect(@service.call 'get', 'greeting').to.be.instanceof mimic.Response
    
  it 'should not be case sensitive', ->
    expect(@service.call 'get', 'GReeTING').to.be.instanceof mimic.Response
    expect(@service.call 'GET', 'greeting').to.be.instanceof mimic.Response
    
  it 'should invoke correct handler based on method and path', ->
    @service.call('get', 'greeting').wait().should.eql
      body: 'Hello World', status: 200

    @service.call('delete', 'greeting').wait().should.eql
      body: 'Goodbye World', status: 200

    @service.call('get', 'fr-greeting').wait().should.eql
      body: 'Bonjour Le Monde', status: 200


  it 'should pass through options', ->
    @service.call('get', 'greeting', name: 'Charles').wait().should.eql
      body: 'Hello Charles', status: 200

    @service.call('delete', 'greeting', name: 'Charles').wait().should.eql
      body: 'Goodbye Charles', status: 200

  it 'should throw error if request does not match schema', ->
    expect(=>
      @service.call('get', 'greeting', count: 123).wait()
    ).to.throw(/Additional properties/)
      
  it 'should use schema to massage data', ->
    res = @service.call('get', 'greeting', number: 12).wait()
    expect(res.body).to.equal 'Hello 35'
  
describe 'Service HTTP Method Helpers', ->
  
  class FullService extends mimic.Service
    
    # API
    @get true
    @put true
    @del true
    @post true
    @head true
    
    onGet: (res) -> res.send(body: 'get')
    onPut: (res) -> res.send(body: 'put')
    onDelete: (res) -> res.send(body: 'delete')
    onPost: (res) -> res.send(body: 'post')
    onHead: (res) -> res.send(body: 'head')

  class NotQuiteFullService extends FullService
    @get false
    
  it 'should handle routes for each type of method', ->
    @service = new FullService(app: mimic)
    ['get', 'put', 'delete', 'post', 'head'].forEach (method) =>
      expect(@service.call(method).wait()?.body, method)
        .to.equal method

  it 'should remove routes when declaring false', ->
    @service = new NotQuiteFullService(app: mimic)
    expect(@service.call('get')).to.be.null
    
  describe 'Basic REST Helpers', ->
  
    class RestService extends mimic.Service
      
      @index   true
      @show    true
      @update  true
      @create  true
      @destroy true
      
      onIndex:   (res, opts) -> res.send(action: 'index',   id: opts.id)
      onShow:    (res, opts) -> res.send(action: 'show',    id: opts.id)
      onUpdate:  (res, opts) -> res.send(action: 'update',  id: opts.id)
      onCreate:  (res, opts) -> res.send(action: 'create',  id: opts.id)
      onDestroy: (res, opts) -> res.send(action: 'destroy', id: opts.id)
    
    handlers =
      index:  { method: 'get', path: '/',  id: undefined }
      show:   { method: 'get', path: '/1', id: '1' }
      update: { method: 'put', path: '/1', id: '1' }
      create: { method: 'post', path: '/', id: undefined }
      destroy:{ method: 'delete', path: '/1', id: '1' }

    beforeEach ->
      @service = new RestService(app: mimic)
      
    for _actionName, _desc of handlers
      ((actionName, desc) ->
       it "should implement #{actionName}", ->
         desc.action = actionName
         method = desc.method
         path   = desc.path
         desc.status = 200
         delete desc.method
         delete desc.path
         
         res = @service.call(method, path, { foo: 'bar' })
         expect(res).to.not.be.null
         expect(res.wait()).to.eql desc
      )(_actionName, _desc) # save context in closure
   

  describe 'Deep REST Helpers', ->
  
    class RestService extends mimic.Service
      
      @index   'users'
      @show    'users'
      @update  'users'
      @create  'users'
      @destroy 'users'

      onIndexUsers:   (res, opts) -> res.send(action: 'index',   id: opts.id)
      onShowUsers:    (res, opts) -> res.send(action: 'show',    id: opts.id)
      onUpdateUsers:  (res, opts) -> res.send(action: 'update',  id: opts.id)
      onCreateUsers:  (res, opts) -> res.send(action: 'create',  id: opts.id)
      onDestroyUsers: (res, opts) -> res.send(action: 'destroy', id: opts.id)
    
    handlers =
      index:   { method: 'get',    path: '/users',   id: undefined}
      show:    { method: 'get',    path: '/users/1', id: '1' }
      update:  { method: 'put',    path: '/users/1', id: '1' }
      create:  { method: 'post',   path: '/users',   id: undefined }
      destroy: { method: 'delete', path: '/users/1', id: '1' }
  
    beforeEach ->
      @service = new RestService(app: mimic)
      
    for _actionName, _desc of handlers
     ((actionName, desc) ->
       it "should implement #{actionName}", ->
         desc.status = 200
         desc.action = actionName
         method = desc.method
         path   = desc.path
         delete desc.method
         delete desc.path
         res = @service.call(method, path, { foo: 'bar' })
         expect(res.wait()).to.eql desc
     )(_actionName, _desc)
   
describe 'JavaScript.extend', ->

  ClassA = MyService.extend ->
    @isOnClass = true
    @::instanceFn = -> 'ClassA'
    expect(@get).to.be.a 'function'
    
    @::init = (args...) ->
      @didInitClassA = true
      ClassA.__super__.constructor.apply(@,args)
    null
    
  ClassB = ClassA.extend ->
    @::instanceFn = -> "ClassB - #{ClassB.__super__.instanceFn.call(@)}"
    @::init = (args...) ->
      @didInitClassB = true
      ClassB.__super__.constructor.apply(@,args)
    null

  it 'should have basic properties hooked up', ->
    expect(ClassA.__super__, 'ClassA.__super__').to.equal MyService.prototype
    expect(ClassA.__super__.constructor, 'ClassA.constructor')
      .to.equal MyService
    
    expect(ClassB.__super__, 'ClassB.__super__').to.equal ClassA.prototype
    expect(ClassB.__super__.constructor, 'ClassB.constructor')
      .to.equal ClassA
    
  it 'should init classA', ->
    expect(-> new ClassA()).to.throw Error
    a = new ClassA(app: mimic)
    a.should.have.property 'didInitClassA', true
    a.should.not.have.property 'didInitClassB'
    ClassA.should.have.property 'isOnClass', true
    a.instanceFn().should.eql 'ClassA'

  it 'should init classB', ->
    should.Throw -> new ClassB()
    b = new ClassB(app: mimic)
    b.should.be.instanceof ClassB
    b.should.have.property 'didInitClassA', true
    b.should.have.property 'didInitClassB', true
    ClassB.should.have.property 'isOnClass', true
    b.instanceFn().should.eql 'ClassB - ClassA'


describe 'exposed helpers', ->
  
  beforeEach -> @service = new MyService(app: mimic)
  it 'should expose request', -> expect(@service.request).to.be.a 'function'
  it 'should expose future', -> expect(@service.future).to.be.a 'function'
  it 'should expose resume', -> expect(@service.resume).to.be.a 'function'
  
  