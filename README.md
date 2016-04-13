# Fleck

**Fleck** is a Ruby gem for comunication over RabbitMQ. It implements both `Fleck::Consumer` for messages consumption from RabbitMQ queues and
`Fleck::Client` for making RPC (Remote Procedure Call) and asynchronous calls.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fleck'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fleck



## Usage

Before using **Fleck** you might want to configure it. For doing that you could use as example the code below:

```ruby
require 'fleck'

# configure defaults for fleck
Fleck.configure do |config|
  config.loglevel      = Logger::INFO # log level
  config.logfile       = STDOUT       # the file where to write the logs
  config.progname      = 'MyApp'      # the progname prefix to use in logs
  config.default_host  = '127.0.0.1'  # default host to use for connections to RabbitMQ
  config.default_port  = 5672         # default port to use for connections to RabbitMQ
  config.default_user  = 'guest'      # default user to use for connections to RabbitMQ
  config.default_pass  = 'guest'      # default password to use for connections to RabbitMQ
  config.default_vhost = '/'          # default vhost to use for connections to RabbitMQ
  config.default_queue = 'default'    # default queue name to use in consumers, when not specified
end
```

### Fleck::Client

You could use **Fleck** for both making requests and consuming requests from the queues. Now we are going to see how to enqueue a request to a specific queue:

```ruby
ACTION  = 'do_something'              # the action to be executed by the consumer
QUEUE   = 'my.queue'                  # the name of the queue where to enqueue the request
HEADERS = {my_header: 'a header'}     # the headers of the request
PARAMS  = {parameter: 'a parameter'}  # the parameters of the request
ASYNC   = false                       # a flag to indicate if the request is async or not


connection = Fleck.connection(host: '127.0.0.1', port: 5672, user: 'guest', pass: 'guest', vhost: '/')
client = Fleck::Client.new(connection, QUEUE)
response = client.request(action: ACTION, headers: HEADERS, params: PARAMS, async: ASYNC)

response.status  # => returns the status code of the response
response.headers # => returns the headers Hash of the response
response.body    # => returns the body of the response
response.errors  # => returns the Array of errors
```

All the options of the requests are optional. The available options for request are:
  - `action`  - (default: nil)  - used to indicate the action to be executed by the consumer
  - `headers` - (default: `{}`) - allows to set headers for the request
  - `params`  - (default: `{}`) - allows to set the parameters of the request
  - `async`   - (default: `false`) - indicates if the request should be executed asynchronously
  - `timeout` - (default: `nil`) - when set, indicates the request timeout in seconds after which the request will be canceled
  - `queue`   - (default: `<client queue>`) - allows to specify a different queue where to enqueue the request

#### Request with block

You might want to process the response of asynchronous requests when the response is ready. In that case you could pass a block to the request,
so that the block is called when the response is completed:

```ruby
client.request(action: 'do_something', headers: {}, params: {param1: 'myparam'}, async: true) do |request, response|
  if response.status == 200
    puts "#{response.status} #{response.body}"
  else
    puts "#{response.status} #{response.errors.join(", ")}"
  end
end
```


### Fleck::Consumer

To use `Fleck::Consumer` all you need is to inherit it by an another class:

```ruby
class MyConsumer < Fleck::Consumer
  configure queue: 'my.queue', concurrency: 2

  def on_message(request, response)
    logger.debug "HEADERS: #{request.headers}"
    logger.debug "PARAMS: #{request.params}"

    case request.action
    when 'random'
      if rand > 0.1
        response.status = 200
        response.body = {x: rand, y: rand}
      else
        response.render_error(500, 'Internal Server Error (just a joke)')
      end
    else
      response.not_found
    end
  end
end
```

This code will automatically automatically start `N` instances of MyConsumer in background (you don't have to do anything), that will start consuming
messages from `my.queue` and will respond with a 200 status when the randomly generated number is greater than `0.1` and with a 500 otherwise.

**NOTE**: the default status code of the response is 200, but if any uncaught exception is raised from within `#on_message` method, the status
 will automatically change to 500 and will add `"Internal Server Error"` message to response errors array.


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/serioja90/fleck. This project is intended to be a safe, welcoming space
for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

