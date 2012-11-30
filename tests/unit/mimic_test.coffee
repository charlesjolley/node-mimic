# Service Helpers are extra functions added beyond the core calling 
# mechanisms.


# Simple echo service identifies itself
METHODS = ['get', 'put', 'post', 'delete'] 
class EchoService extends mimic.Service
  METHODS.forEach (method) =>
    @[method] (res, opts) -> 
      opts.serviceId = @id; 
      opts.serviceTier = @tier
      res.send(opts)
  
describe 'config method', ->
  beforeEach -> @intern = mimic()
  
  describe 'add', ->
    
    it 'should mount the service at the named location on default tier', ->
      ret = @intern.add 'echo', EchoService
      expect(ret, 'return value').to.equal @intern # for chaining
  
      service = @intern.services?.echo
      expect(service, 'intern.services.echo').to.be.instanceof EchoService
      expect(service.id, 'service.id').to.equal 'echo'
      expect(service.tier, 'service.tier').to.equal.default
      
    it 'should anonymous service and return instance', ->
      ret = @intern.add EchoService
      expect(ret, 'return value').to.be.instanceof EchoService
      expect(ret.id, 'ret.id').to.not.be.null
      expect(@intern.services[ret.id], '@intern.service').to.equal ret
      expect(ret.tier, 'ret.tier').to.equal 'default'
  
    it 'should accept a named tier', ->
      @intern.add 'east', 'echo', EchoService
      expect(@intern.services.echo.tier, 'tier').to.equal 'east'
      
  describe 'remove', ->
    beforeEach -> @intern.add 'echo', EchoService

    it 'should remove named service', ->
      ret = @intern.remove 'echo'
      expect(ret, 'return value').to.be.instanceof EchoService
      expect(@intern.services.echo).to.be.undefined
      
    it 'should remove anonymous service', ->
      ret = @intern.add EchoService
      expect(@intern.services[ret.id], 'anonymous service').to.equal ret
      
      ret2 = @intern.remove ret.id
      expect(ret2, 'return value 2').to.equal ret
      expect(@intern.services[ret.id], 'services').to.be.undefined
      

describe 'request', ->
  beforeEach ->
    @intern = mimic().add('echo1', EchoService).add('echo2',EchoService)
    
  it 'should return a wrapper with the correct service selected', ->
    expect(@intern.request('echo1').service, 'request(echo1)')
      .to.equal @intern.services.echo1

    expect(@intern.request('echo2').service, 'request(echo2)')
    .to.equal @intern.services.echo2
    
  METHODS.forEach (method) ->
    it "should be able to invoke method '#{method}'", ->
      req = @intern.request('echo1')
      result = req[method](pass: 'through').wait()
      expect(result, method).to.eql
        status:      200
        serviceId:   'echo1'
        serviceTier: 'default'
        pass:        'through'
        method:      method
        path:        '/'

      req = @intern.request('echo2')
      expect(req[method]().wait().serviceId, 'echo2').to.equal 'echo2'        


_timeout = (arg, done) -> setTimeout((-> done(null, arg)), 20)

describe 'future helper', ->
  beforeEach -> @mimic = mimic()
  it 'should return a future and eventually resume', ->
    fut = @mimic.future(_timeout('foo', @mimic.resume))
    expect(fut, 'return value').to.be.instanceof mimic.Future
    expect(fut.isResolved(), 'isResolved').to.be.false
    expect(fut.wait(), 'resolved value').to.equal 'foo'
    
  it 'should work twice', ->
    fut1 = @mimic.future(_timeout('foo', @mimic.resume))
    fut2 = @mimic.future(_timeout('bar', @mimic.resume))

    expect(fut2.wait(), 'resolved value2').to.equal 'bar'
    expect(fut1.wait(), 'resolved value1').to.equal 'foo'

    
    