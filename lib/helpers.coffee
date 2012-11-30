
Future  = require 'fibers/future'

# makes a resume function that will resume a future
# attached to it if possible.
_makeResume = ->
  fn = (err, val) ->
    return if fn.fired
    fn.fired = true
    if fn.future
      if err then fn.future.throw(err) else fn.future.return(val)
    else fn.done = { err: err, val: val }

# Helpers
exports.future = () ->
  future = new Future()
  resume = future.resume = @resume
  @resume = _makeResume() # replace for next caller

  if done = resume?.done
    if done.err then future.throw(done.err) else future.return(done.val)
  else if resume then resume.future = future
  future

exports.makeResume = _makeResume
