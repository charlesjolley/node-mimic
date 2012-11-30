connect = require 'connect'
Future  = require 'fibers/future'
helpers = require './helpers'

PROPS =
  Future:       Future
  Service:      require './service'
  FiberService: require './fiber_service'
  Response:     require './response'
  Request:      require './request'

  add: (tier, name, ServiceClass) ->
    if arguments.length == 1
      ServiceClass = tier
      inst = if tier instanceof @Service then tier else null
      inst ||= new ServiceClass(app: @)
      @services[inst.id] = inst
      inst
    else
      if undefined == ServiceClass and 'string' != typeof name
        ServiceClass = name
        name = tier
        tier = 'default'
      
      inst = new ServiceClass(app: @, id: name, tier: tier)
      @services[inst.id] = inst
      @
      
  remove: (name) ->
    inst = @services[name]
    delete @services[name]
    inst
        
  request: (name) ->
    throw new Error("Service '#{name}' Not Found") if not @.services[name]
    new @Request(@, @.services[name])

  future: helpers.future
  
module.exports = mimic = ->
  fn = connect()
  fn[key] = value for key, value of PROPS
  fn.resume = helpers.makeResume() # be ready!
  fn.services = {}
  fn

mimic[key] = value for key, value of PROPS  
