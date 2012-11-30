# The Plan

## RemoteService

When you add service to a remote tier, create a RemoteService instance instead
which will marshall your data and send it over to the other listener.

Implement default middleware in the mimic() object that will respond to the 
inbound request and activate the appropriate service.

Check in development mode every call to every service, even local ones, to
ensure only JSON-serializable objects are passed in so that we can marshall
them.

## Automatic Tier Config

Add option to automatically pull tier config from a remote server. API would
let you supply local service that responds to get('config') which should
return the overall config API. The service should also respond start() and 
stop() to listen for config changes.

On config change, mimic should teardown it's current set of services and 
rebuild them with the new config.

## Service Bridge Middleware

Create middleware to bridge a call from the outside to a call to an internal
service. This would allow you to create 'intern' and 'public' services. Public
services would be visible to the outside world and could call intern.

    class PublicUserService extends FiberService
    
      @show (res, opts) ->
        viewer = @intern.request('auth')
          .get(opts.params.token).wait()?.viewer
        user = @intern.request('users')
          .get(opts.id, viewer: viewer).wait()?.body
        # do other validation / strip private data, etc.
        res.send 200, $meta: { main: 'user' }, user: user

    intern = mimic()
      .add 'users', InternUserService
      .add 'auth',  InternAuthService
      
    public = mimic()
      .add 'users', PublicUserService
      
    app = express()
    app.use express.methodOverride()
    # other middleware
    app.use '/api', public # tada! public services now available
    app.createServer(...)
    
 