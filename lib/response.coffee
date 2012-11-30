Future = require 'fibers/future'
http   = require 'http'

class Response extends Future
  constructor: (service) ->
    super
    @service = service

  send: (data={}) ->
    data.status = 200 if not data.status
    data.status = Number(data.status) # must be a number
    if data.status < 400 then @return(data) else
      message = http.STATUS_CODES[data.status]
      err = new Error(http.STATUS_CODES[data.status] or 'Unknown Error')
      err[key] = value for key, value of data
      @throw err
    @
    
        
module.exports = Response
