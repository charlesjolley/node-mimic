Service = require './service'

class FiberService extends Service
  constructor: -> super; @usesFibers = true; @  
      
module.exports = FiberService
