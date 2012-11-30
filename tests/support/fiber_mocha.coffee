# Adds fiber support for Mocha. This allows you to use the fiber wait() 
# function to wait on tests instead of writing nested functions

Fiber        = require 'fibers'
Future       = require 'fibers/future'

# handles Future.wait, but also if you pass
# an fn, will invoke the fn with passed arguments
# and wait on a response. raises and error if
# there is one. usage:
#
#   dirs = wait fs.readdir, '.'
#
# note that this is not like sync because it actually
# runs async
# global.wait = (fn, args...) ->
#   if 'function' == typeof fn
#     Future.wrap(fn)(args...).wait()
#   else
#     Future.wait(fn, args...)

# modify mocha tests to wrap each sync test in a
# fiber. this will allow us to yield, wait, and resume
Runnable = require 'mocha/lib/runnable'
_run = Runnable.prototype.run

Runnable.prototype.run = (fn) ->
  if not @fiberReady
    @fiberReady = true
    _fn = @fn

    if @sync
      @async = true
      @sync  = false
      @fn = (done) -> 
        Fiber(() => 
          try
            _fn.call(@)
            done()
          catch e
            done e
        ).run()
    else
      @fn = (done) -> 
        Fiber(() => 
          try
            _fn.call @, done
          catch e
            done e
        ).run()

  _run.call @,fn
