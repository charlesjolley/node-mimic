# Mimic

Mimic is a framework for writing lightweight internal web services. Mimic makes it easy to build an application that is naturally testable and easily scales across multiple tiers.

## How Does It Work?

Mimic works similarly to connect() except that it does not use an explicit request / response structure, since it is not intended to actually go over HTTP in most cases.

Here's how you do it. First, define an app:

    var intern = mimic();
    
Then define a service:

    var MyService = mimic.Service.extend(function() {
      this.get('say_hello', function(res, opts) {
        res.send({ body: "Hello "+opts.name });
      });
    });
    
You can also use CoffeeScript:

    class MyService extends mimic.Service
      @get 'say_hello', (res, opts) ->
        res.send(body: "Hello #{opts.name}")

Register your service with the app. This isn't a path, it's just the name 
of your service since this usually won't go over the network:

    intern.add('my_service', MyService);
    
Now you can send a request. The request returns a future that will resolve
later:

    req = intern.request('my_service').get('say_hello', { name: 'Charles' });
    req.done(function(err, response) { console.log(response.body); });
    
# Calling Other Services

You can easily call other services within your own service. This chaining 
concept is what makes mimic work:

    var uuid = require('uuid').v4;
    var RoomService = mimic.Service.extend(function() {

      function _saveToDb(roomId, msg, done) { ... }
      
      // once we save the message to the database, send a push notification
      this.post(':roomId/messages', function(res, opts) {
        var app = this;
        var msg = opts.body;
            msg.id = uuid();

        _saveToDb(opts.roomId, msg, function(err) {
          return res.send(err) if err; // pass error back to sender
          
          // send a push notification, wait until the service returns...
          var req = app.request('push')
          req.post('message', { room: roomId, body: msg }).done(function(err){
            res.send(err);
          });
      });
    });

Or as CoffeeScript:

    uuid = require('uuid').v4
    class RoomService extends mimic.Service
    
      _saveToDb = (roomId, msg, done) -> ...
      
      @post ':roomId/messages', (res, opts) ->
        msg = opts.body
        msg.id = uuid()
        
        _saveToDb opts.roomId, msg, (err) =>
          return res.send(err) if err
          @request('push').post(room: roomId, body: msg).done (err) ->
            res.send err
            
# Splitting Your App By Tiers

> **NOTE**: Remote service support is not yet implemented. This section 
> describes how I intend the feature to work in the future.
   
So far, so good. But why is this useful? Well, for one thing, it's easy to 
split mimic services into tiers once you start to scale. Just tier locations when you create your instance and then register your services with tier names:

    var intern = mimic({ 
      // this is the tier the current instance belongs to
      tier: 'chat_tier', 
      
      // defines how to reach all other tiers
      tiers: { 
        'chat_tier': 'http://chat001.myapp.com:5050/intern',
        'auth_tier': 'http://auth001.myapp.com:5050/intern'
      }
    });
    
    intern.add('auth_tier', 'users',  UserService)
          .add('auth_tier', 'tokens', TokenService)
          .add('chat_tier', 'rooms',  RoomService)
          .add('chat_tier', 'push',   PushService);
          
For services in your local tier, this will create local instances like normal.
For services in remote tiers, it will serialize your requests and send them 
over the wire to the other tier.

To make your tier available to others, you will also need to start a server instance to listen for incoming connections. The mimic object is connect middleware, so it's easy to do this:

    var connect = require('connect');
    connect().use('/intern', intern).createServer(5050, function() {
      console.log("Listening for internal tier: " + intern.tier);
    });
    
# Fibers

The FiberService class allows you to also use fibers when writing services,
which makes it simple to write async code without as many callback functions.
For example, here is the RoomService example above:

    class RoomService extends mimic.FiberService
    
      # returns a future
      _saveToDb = (roomId, msg) -> ...
  
      # any exceptions raised will automatically return an error
      @post ':roomId/messages', (res, opts) ->
        msg = opts.body
        msg.id = uuid()
        _saveToDb(roomId, msg).wait() # yields fiber
        @request('push').post(room: roomId, body: msg).wait()
        res.send(200) 

If you want to wrap a function with a callback, you can do so with the @future and @resume helpers:

        // read directories async, pause in fiber
        var filenames = this.future(fs.readdir(__dirname, this.resume).wait();
        
in CoffeeScript:

        # read directories async, pause in fiber
        filenames = @future(fs.readdir(__dirname, @resume).wait()
        
