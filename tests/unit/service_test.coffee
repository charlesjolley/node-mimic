
class MyService extends mimic.Service

  @get 'greeting', (res, opts) -> 
    res.send(body: "Hello #{opts.name || 'World'}")

  @get 'fr-greeting', (res, opts) ->
    res.send(body: "Bonjour #{opts.name || 'Le Monde'}")
    
  @['delete'] 'greeting', (res, opts) -> 
    res.send(body: "Goodbye #{opts.name || 'World'}")

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
    should.Throw -> new MyService(id: 'service', tier: 'default')
    
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
    @get 'greeting', (res, opts) -> # new fn
    @get 'fr-greeting/:name', (res, opts) ->

  beforeEach ->
    @service = new MyService(app: mimic, id: 'service', tier: 'default')
    @child   = new ChildService(app: mimic, id: 'child', tier: 'default')
  
  it 'should return a method for defined route', ->
    paths = ['greeting', '/greeting', 'GREETING', '/GREETING',
              '/Greeting/', '/GREETING/./', 'NOT/../greeting']
    
    paths.forEach (path) =>
      expect(@service.route('get', path), "get #{path}").not.to.be.null
    expect(@service.route('delete', 'greeting'), "del greeting").not.to.be.null
    fn1 = @service.route('get', 'greeting')[0]
    fn2 = @service.route('delete', 'greeting')[0]
    expect(fn1, 'get vs del handlers').to.not.equal fn2
    
  it 'should add method and path to opts', ->
    opts = @service.route('GET', '/greeting')[1]
    expect(opts).to.have.keys 'method', 'path'
    opts.method.should.eql 'get'
    opts.path.should.eql '/greeting'
    
  it 'should handle inheritance', ->
    serviceFn = @service.route 'get', 'greeting'
    childFn   = @child.route   'get', 'greeting'
    expect(childFn, 'child.greeting v parent.greeting').not.to.eql serviceFn
    
    serviceFn = @service.route 'get', 'fr-greeting/:name'
    childFn   = @child.route   'get', 'fr-greeting/:name'
    expect(serviceFn, 'child route in parent').to.be.null
    expect(childFn, 'child route in child').not.to.be.null
    
  it 'should handle wildcards', ->
    plainFn = @child.route 'get', 'fr-greeting'
    wildFn  = @child.route 'get', 'fr-greeting/charles'
    
    expect(plainFn, 'child.fr-greeting').not.to.be.null
    expect(wildFn, 'child.fr-greeing/charles').not.to.be.null
    expect(wildFn[0], 'handler functions').not.to.equal plainFn[0]
    wildFn[1].should.have.property 'name', 'charles'

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

describe 'Service HTTP Method Helpers', ->
  
  class FullService extends mimic.Service
    
    @get (res) -> res.send(body: 'get')
    @put (res) -> res.send(body: 'put')
    @['delete'] (res) -> res.send(body: 'delete')
    @post (res) -> res.send(body: 'post')
    @head (res) -> res.send(body: 'head')

  it 'should handle routes for each type of method', ->
    @service = new FullService(app: mimic)
    ['get', 'put', 'delete', 'post', 'head'].forEach (method) =>
      expect(@service.call(method).wait()?.body, method)
        .to.equal method

  describe 'Basic REST Helpers', ->
  
    class RestService extends mimic.Service
      
      @index  (res, opts) -> res.send(opts)
      @show   (res, opts) -> res.send(opts)
      @update (res, opts) -> res.send(opts)
      @create (res, opts) -> res.send(opts)
      @del    (res, opts) -> res.send(opts)
    
    handlers =
      index:  { method: 'get',  path: '/' }
      show:   { method: 'get',  path: '/1', id: '1' }
      update: { method: 'put',  path: '/1', id: '1' }
      create: { method: 'post', path: '/' }
      del:    { method: 'delete', path: '/1', id: '1' }

    beforeEach ->
      @service = new RestService(app: mimic)
      
    for actionName, desc of handlers
     it "should implement #{actionName}", ->
      desc.status = 200
      desc.foo = 'bar'
      res = @service.call(desc.method, desc.path, { foo: 'bar' })
      expect(res.wait()).to.eql desc
   

  describe 'Deep REST Helpers', ->
  
    class RestService extends mimic.Service
      
      @index  'users', (res, opts) -> res.send(opts)
      @show   'users', (res, opts) -> res.send(opts)
      @update 'users', (res, opts) -> res.send(opts)
      @create 'users', (res, opts) -> res.send(opts)
      @del    'users', (res, opts) -> res.send(opts)
    
    handlers =
      index:  { method: 'get',  path: '/users' }
      show:   { method: 'get',  path: '/users/1', id: '1' }
      update: { method: 'put',  path: '/users/1', id: '1' }
      create: { method: 'post', path: '/users' }
      del:    { method: 'delete', path: '/users/1', id: '1' }
  
    beforeEach ->
      @service = new RestService(app: mimic)
      
    for actionName, desc of handlers
     it "should implement #{actionName}", ->
      desc.status = 200
      desc.foo = 'bar'
      res = @service.call(desc.method, desc.path, { foo: 'bar' })
      expect(res.wait()).to.eql desc
   

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
    should.Throw -> new ClassA()
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
  
  