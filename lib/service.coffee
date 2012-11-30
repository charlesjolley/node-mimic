
uuid   = require('node-uuid').v4
path   = require 'path'
Houkou = require 'houkou'
Response = require './response'
helpers = require './helpers'
Fiber  = require 'fibers'

_normalizeRouteName = (routeName) ->
  '/'+path.normalize(routeName.toLowerCase()).replace(/^\/?(.*?)\/?$/, '$1')

_merge = (base, ext) -> base[key] ||= value for key, value of ext
  
_nargs = (routeName, fn) ->
  if undefined == fn and 'function' == typeof routeName
    fn = routeName
    routeName = '/'
  [routeName, fn]


class Service
  constructor: (opts={}) ->
    throw new Error("You must pass a mimic instance as 'app'") unless opts.app
    @app  = opts.app
    @id   = opts.id or uuid()
    @tier = opts.tier or 'default'
    @href = opts.href or "mimic:#{@id}.#{@tier}"
    @resume = helpers.makeResume()
    @usesFibers = no
  
  call: (method, routeName, opts) ->
    if undefined == opts and 'string' != typeof routeName
      opts = routeName
      routeName = '/'
    opts = {} if not opts
    
    [fn, params] = @route(method, routeName) || []
    return null if not fn
    _merge params, opts
    res = new Response @

    # makes these calls truly async. This way the flow control
    # remains the same whether the service is local or not.
    process.nextTick =>
      if @usesFibers
        Fiber( =>
          try
            fn.call @, res, params
            Fiber.yield() unless res.isResolved()
          catch e
            res.throw e
        ).run()
      else
        fn.call @, res, params
    res

  route: (method, routeName) ->
    method = method.toLowerCase()
    routeName = _normalizeRouteName(routeName)
    routes = @constructor.getRoutes()?[method]
    return null if not routes
    for key, route of routes
      continue if not params = route.match routeName
      params.method = method
      params.path   = routeName
      return [route.fn, params]
    null
  
  request: (args...) -> @app.request(args...)

  future: helpers.future

  # ensures the passed property is unique to this class on the prototype.
  @getRoutes = ->
    SuperClass = @.__super__?.constructor
    routes     = @.__routes__
    if not routes or (routes == SuperClass?.__routes__)
      if 'function' == typeof SuperClass?.getRoutes
        routes = Object.create SuperClass.getRoutes()
        routes[key] = Object.create(hash) for key, hash of routes
      else routes = {}
      @.__routes__ = routes
    routes


  # Duplicate CoffeeScript extend & super. Allows you to use this with
  # JavaScript as well.
  _hasProp = {}.hasOwnProperty
  _extends = (child, parent) ->
    for key,val of parent
      child[key]=val if _hasProp.call(parent,key)
    ctor = -> @constructor = child; @
    ctor.prototype = parent.prototype
    child.prototype = new ctor()
    child.__super__ = parent.prototype
    child

  @extend = (fns...) ->
    Child = (args...) -> Child::init(args...) if Child::init; @

    _extends Child, @
    Child::init = (args...) -> Child.__super__.constructor.apply(@, args)

    fns.forEach (fn) ->
      if 'function' == typeof fn then fn = fn.call(Child)
      if 'object' == typeof fn then Child.prototype[k]=v for k,v of fn

    Child

  
  ## DSL
  ['get', 'delete', 'post', 'put', 'head'].forEach (method) =>
    @[method] = (routeName, fn) ->
      [routeName, fn] = _nargs routeName, fn
      routes = @getRoutes()
      routes[method] = {} if not routes[method]
      routeName = _normalizeRouteName routeName
      routes[method][routeName] = new Houkou(routeName)
      routes[method][routeName].fn = fn
      @
    
  ## REST Helpers
  @index = (routeName, fn) ->
    [routeName, fn] = _nargs routeName, fn
    @get routeName, fn
      
  @show = (routeName, fn) ->
    [routeName, fn] = _nargs routeName, fn
    @get "#{_normalizeRouteName routeName}/:id", fn

  @update = (routeName, fn) ->
    [routeName, fn] = _nargs routeName, fn
    @put "#{_normalizeRouteName routeName}/:id", fn

  @create = (routeName, fn) ->
    [routeName, fn] = _nargs routeName, fn
    @post routeName, fn

  @del = (routeName, fn) ->
    [routeName, fn] = _nargs routeName, fn
    @['delete'] "#{_normalizeRouteName routeName}/:id", fn
    
module.exports = Service
    