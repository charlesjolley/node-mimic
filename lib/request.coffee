

class Request
  
  constructor: (app, service) ->
    @app = app
    @service = service
    
  _handlerFor = (method) -> (args...) -> @service.call(method, args...)
  get:  _handlerFor 'get'
  put:  _handlerFor 'put'
  post: _handlerFor 'post'
  'delete': _handlerFor 'delete'
  head: _handlerFor 'head'

  _norm  = (name, id, args) ->
    if 'string' != typeof id
      args.unshift id
      id = name
      name = '/'
    args.unshift "#{resourceName}/#{id}"
    args
    
  # rest methods
  index: (args...) -> @service.call 'get', args...

  show: (name, id, args...) -> 
    @service.call 'get', _norm(name, id, args)
    
  create: (args...) -> @service.call 'post', args...
  update: (name, id, args) ->
    @service.call 'put', _norm(name, id, args)
    
  del: (name, id, args) ->
    @service.call 'delete', _norm(name, id, args)

    
module.exports = Request