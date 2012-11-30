Service = require './Service'

# create an instance of this class with a remote URL.
# call() will marshall your data and send it across the wire.
class RemoteService
  
  constructor: (opts) ->
    super
    remote = opts.remote
    throw new Error('Remote address required for RemoteService') if not remote
    
  call: (method, routeName, opts) ->
    # TODO:
    # - marshall opts into JSON.
    # - connect to remote service. send there.
    throw new Error('Remote Service Not Yet Implemented')
  