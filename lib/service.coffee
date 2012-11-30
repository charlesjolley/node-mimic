###
# Service

You define a service by extending this class.
###

uuid   = require('node-uuid').v4
path   = require 'path'
Houkou = require 'houkou'
Response = require './response'
helpers = require './helpers'
Fiber  = require 'fibers'
lingo  = require 'lingo'
contracts = require 'contracts'

_normalizeRouteName = (routeName) ->
  '/'+path.normalize(routeName.toLowerCase()).replace(/^\/?(.*?)\/?$/, '$1')

_merge = (base, ext) -> base[key] ||= value for key, value of ext
  

class Service
  ### 
  Core service class. Subclass this to build your own service. You will 
  typically want to define your API first and then define handler methods
  for each incoming message.
  ###
    
  constructor: (opts={}) ->
    ###
    Normally you will not instantiate a service directly, however you may
    override the constructor to take additional options if you want.
    ###
    
    throw new Error("You must pass a mimic instance as 'app'") unless opts.app
    @app  = opts.app
    @id   = opts.id or uuid()
    @tier = opts.tier or 'default'
    @href = opts.href or "mimic:#{@id}.#{@tier}"
    @resume = helpers.makeResume()
    @usesFibers = no
  
  call: (method, routeName, opts) ->
    ###
    Primary entry point for invoking actions on the service. This accepts a 
    method, routeName and any additional options. This method will use the 
    defined routes to map your call to a local function, then validate your
    options through a schema if provided, and finally invoke the actual method
    on a next run on the process loop.
    
    If you use the FiberService class, this will also start your handler
    inside of a new fiber.
    ###
    
    if undefined == opts and 'string' != typeof routeName
      opts = routeName
      routeName = '/'
    opts = {} if not opts
    
    throw new Error("Method required") if not method
    
    {fn, params, schema} = @route(method, routeName) || []
    fn = @[fn] if 'string' == typeof fn
      
    return null if not fn
    _merge params, opts
    report = contracts.validate params, schema
    
    if report.errors?.length > 0
      message = report.errors.map (err) -> 
        "#{err.uri.replace /^.+\#/, ''}: #{err.message}"
      err = new Error(message.join "\n")
      err.report = report.errors
      throw err

    params = report.instance
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
    ###
    Resolves a method/routeName to an actual implementation function.
    Also extracts params and a potential schema.
    
    **Returns**:
    
        fn     # the function
        params # parameters extracted from the route
        schema # a schema if defined
    ###
    
    method = method.toLowerCase()
    routeName = _normalizeRouteName(routeName)
    routes = @constructor.getRoutes()?[method]
    return null if not routes
    for key, route of routes
      continue unless route and (params = route.match routeName)
      return { fn: route.fn, params: params, schema: route.schema }
    null
  
  
  request: (args...) -> 
    ###
    Returns a new request object that you can use to make a request of another
    service. Pass the name of the service you want to target or a URL.
    ###
    @app.request(args...)

  future: (fn) ->
    ###
    Returns a future, wrapping the function call you pass in here. You must
    pass `@resume` for a callback function in the main call.
    
    **Example:**
        # reads the directory files async, using a fiber to wait
        dirs = @future(fs.readdir('.', @resume)).wait()
    ###
    helpers.future.call @, fn

  @getRoutes = ->
    ### 
    **PRIVATE** Ensures the passed property is unique to this class on the 
    prototype.
    ###

    SuperClass = @.__super__?.constructor
    routes     = @.__routes__
    if not routes or (routes == SuperClass?.__routes__)
      if 'function' == typeof SuperClass?.getRoutes
        routes = Object.create SuperClass.getRoutes()
        routes[key] = Object.create(hash) for key, hash of routes
      else routes = {}
      @.__routes__ = routes
    routes


  ##################################################
  ## extend helper
  ##

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
    ###
    Implements CoffeeScript-like API for extending the class. Useful
    for when you want to write your service in JavaScript.
      
    Note that since there is not explicit support for super, you will
    need to do it yourself. See example below.
    
    **Example:**
    
        // function will be called with `this` set to the new Class
        var MyService = Service.extend(function() {
          
          // define API
          this.get 'hello'

          // return instance properties to add to prototype
          return {
            
            // override constructor.
            init: function() {
              // call super
              MyService.__super__.constructor.apply(this, arguments);
              this.name = 'Charles'
            },
              
            // handler
            onGetHello: function(res) {
              res.send({ body: 'hello ' + this.name; });
            }
          };
        });
    ###
    Child = (args...) -> Child::init(args...) if Child::init; @

    _extends Child, @
    Child::init = (args...) -> Child.__super__.constructor.apply(@, args)

    fns.forEach (fn) ->
      if 'function' == typeof fn then fn = fn.call(Child)
      if 'object' == typeof fn then Child.prototype[k]=v for k,v of fn

    Child

  
  ##################################################
  ## DSL for defining API.
  ##

  ###
  Call options:
  
    # get '/' - standard schema - invoke doGet()
    @get true
    
    # get '/foo' - standard schema - invoke doGetFoo()
    @get 'foo' # means - I support this path 'foo'
    
    # get '/' - standard schema, invoke doFoo()
    @get(method: 'doFoo')
    
    # get '/foo/:id' - standard schema w/ id param. invoke doMyFoo
    @get '/foo/:id', method: 'doMyFoo'
    
    @get # any property except method --> schema
  ###
    
  _nargs = (routeName, opts) ->
    ### **PRIVATE** - normalizes arguments passed to API methods ###
    if undefined == opts and 'string' != typeof routeName
      opts = routeName
      routeName = '/'
      
    return [routeName, false] if opts == false
    opts = null if opts == true
    [routeName, opts || {}]
    
  _fnName = (methodName, routeName, opts) ->
    ### **PRIVATE** - generate fnName from routeName ###
    return opts.method if opts.method
    routeName = routeName.replace(/\/:[^\/]+/g, '').replace(/[\/\-_]/g,' ')
    routeName = lingo.camelcase routeName, true
    "on#{lingo.capitalize methodName}#{routeName}"
    
  _makeSchema = (opts, routeName, parameters) ->
    if opts and opts.hasOwnProperty 'method'
      if Object.keys(opts).length == 1 then opts = null
      else delete opts.method
    return opts if opts and Object.keys(opts).length>0
    
    properties = {}
    parameters.forEach (pname) -> 
      properties[pname] = { type: 'string', required: true }
      
    # generate schema
    type: 'object'
    additionalProperties: yes
    properties: properties


  ['get', 'del', 'post', 'put', 'head'].forEach (method) =>
    httpMethod = if 'del' == method then 'delete' else method
    @[method] = (routeName, opts) ->
      [routeName, opts]  = _nargs routeName, opts
      routeName          = _normalizeRouteName routeName
      route              = new Houkou(routeName)
      routes             = @getRoutes()
      routes[httpMethod] = {} if not routes[httpMethod]

      if opts == false
        routes[httpMethod][routeName] = null # don't delete - inherited
      else
        route.fn     = _fnName httpMethod, routeName, opts
        route.schema = _makeSchema opts, routeName, route.parameters
        routes[httpMethod][routeName] = route
      @
    
  ## REST Helpers
  @index = (routeName, opts) ->
    [routeName, opts] = _nargs routeName, opts
    opts.method = _fnName('index', routeName, opts) unless opts == false
    @get routeName, opts
      
  @show = (routeName, opts) ->
    [routeName, opts] = _nargs routeName, opts
    opts.method = _fnName('show', routeName, opts) unless opts == false
    @get "#{_normalizeRouteName routeName}/:id", opts

  @update = (routeName, opts) ->
    [routeName, opts] = _nargs routeName, opts
    opts.method = _fnName('update', routeName, opts) unless opts == false
    @put "#{_normalizeRouteName routeName}/:id", opts

  @create = (routeName, opts) ->
    [routeName, opts] = _nargs routeName, opts
    opts.method = _fnName('create', routeName, opts) unless opts == false
    @post routeName, opts

  @destroy = (routeName, opts) ->
    [routeName, opts] = _nargs routeName, opts
    opts.method = _fnName('destroy', routeName, opts) unless opts == false
    @del "#{_normalizeRouteName routeName}/:id", opts
    
module.exports = Service
    