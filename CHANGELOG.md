# CHANGELOG #

## develop ##

### TAGS ###

Below you can see the CHANGELOG of **Fleck** gem by version number.

#### v2.2.0 (22 Dicember 2022) #####

- **NEW** Implemented the feature which allows to add a modifier `lambda` to `param` decorator,
          so that the value of parameter can be modified before proceeding with action execution.
          Example: `param :name, ->(v) { v.to_s.strip.downcase }` will automatically convert the value of `name` parameter to string, will remove heading and trailing spaces and will transform to lower case.
- **FIX** Correctly perform param `:max` validation.
- **FIX** Move `HashWithIndifferentAccess` class under `Fleck` module, in order to avoid conflict with `ActiveSupport::HashWithIndifferentAccess`.

#### v2.1.3 (10 February 2022) #####

- **FIX** Correct nesting for `Fleck::HostRating` methods, in order to have correct context and visibility.

#### v2.1.2 (10 February 2022) ####

- **FIX** Autoload Fleck::HostRating from `fleck.rb`, instead of autoloading it from `configuration.rb`.

#### v2.1.1 (9 February 2022) ####

- **FIX** Correctly handle cases when `#ok!` helper method is used and a hash body is passed as argument.

#### v2.1.0 (9 February 2022) ####

- **NEW** Added automatic params and headers logging when logger level is set to DEBUG.

#### v2.0.0 (31 Jannuary 2022) ####

- **BREAKING CHANGE** Updated minimum required Ruby version to >= 2.5.
- **NEW** Refactored `Fleck::Consumer` in order to have a better code structure.
- **NEW** Implemented response helpers, which allow to terminate the request with desired status code and message.
- **NEW** Implemented action decorators, which allow to define an action and it's parameters directly before the method.
- **NEW** Implemented action params automatic validation, which can be set by using action decorators.

#### v1.0.1 (2 April 2020) ####

- **BREAKING CHANGE** Updateg gemset, in order to be able to use new versions of Ruby.

#### v0.7.0 (21 June 2016) ####

- **NEW** Added multihost support to Fleck configuration, that allows to manage network failure situations and to choose the best options from the list of available hosts.
          This feature uses `Fleck::HostRating` to collect TCP latency data about each provided host, so that when a new connection is required, the host with lowest latency
          will be choosed. If a host becomes unreachable, it gets the lowest rating and will be used as the last option, allowing you to automatically manage network failures.
- **NEW** Implemented a basic log filter for headers and params in requests and responses.
- **NEW** Log each processed request in `Fleck::Consumer::Response`.
- **NEW** Implemented `:deprecated?` method for `Fleck::Consumer::Response`.
- **NEW** Store client IP address to requests headers, in order to be able to trace requests origin when multiple clients making requests to the same consumer type.

#### v0.6.0 (16 June 2016) ####

- **NEW** __(BREAKING CHANGE)__ Use `"fleck"` exchange for RPC simulation, so that reply queues could be used in a RabbitMQ Federation configuration.
          Be careful when upgrading `Fleck::Consumer` from version `v0.5.x` or below, because now `Fleck::Consumer` will send responses to a `:direct` exchange
          named `"fleck"`. If there're `Fleck::Clients` that are at version `v0.5.x` or below, they will not be able to receive the response from consumers of a
          newer version.
- **NEW** Added a filter that prevents from using reserved `Fleck::Consumer` methods as actions.
- **NEW** Implemented the feature that allows to start consumer in a blocking way.
- **NEW** Added `:prefetch` and `:mandatory` options to `Fleck::Consumer` configuration options.

#### v0.5.1 (20 April 2016) ####

- **FIX** Don't expire requests with multiple responses if any response is received. Treat that kind of request as expired if no response has been received
          until the request expiration.

#### v0.5.0 (20 April 2016) ####

- **NEW** Added `:autostart` option to `Fleck::Consumer` configuration, so that the developer could decide to start the consumer manually or automatically. By default
          the consumer will start automatically.
- **NEW** Implemented the feature that allows to define an initialization block for `Fleck::Consumer`. This feature should be used to initialize consumer instance
          variables so that it is not necessary to overwrite `Fleck::Consumer#initialize` method.
- **NEW** Implemented the feature that allows to define a map of actions to consumer methods, so that requests actions are automatically mapped to
          consumer methods.
- **NEW** Implemented `#expired?` method for `Fleck::Client::Request`, that tells if the request is expired or not. It makes possible to
          distinguish service unavailable responses from expired requests.
- **NEW** Added `:concurrency` option to `Fleck::Client`, that allows to specify the concurrency level for responses parsing.
- **NEW** Add `:version` option to `Fleck::Client#request` and implement `#version` method for `Fleck::Consumer::Request`.
- **NEW** Implemented `#request` and `#response` methods for `Fleck::Consumer`, so that you don't have to pass them as argument every time you
          delegate the logic to a different method.
- **NEW** Implemented the feature that allows to deprecate actions within a consumer. Now you can call `deprecated!` inside a consumer to
          reply with a response that is marked as **deprecated**.
- **NEW** Add `app_name` configuration, that allows to configure the default `app_id` to set for RabbitMQ messages.
- **NEW** Add process ID to logs, so that if you have multiple instances of the same application writting to the same log file, you'll be able to filter logs by process ID. Also changed logs format.

#### v0.4.1 (18 April 2016) ####

- **FIX** Fixed a bug of `Fleck::Consumer::Request` class, that was causing errors when RabbitMQ message header wasn't set.

#### v0.4.0 (15 April 2016) ####

- **NEW** Support different types of exchanges in both `Fleck::Client` and `Fleck::Consumer`.
- **FIX** Use `auto_delete` queue for `Fleck::Client`, so that it is deleted when the client is terminated.
- **NEW** Add `:rmq_options` option to `Fleck::Client::Request`, which can be used to pass options like `:persistent`, `mandatory`, etc.
          to RabbitMQ message on publish.
- **NEW** Store `:headers` attribute of `Fleck::Client::Request` into RabbitMQ message `:headers`, so that in the future only
          `:params` option will be converted to JSON.
- **NEW** Add `:action` option to `Fleck::Client::Request`, which will replace the action passed within `:headers` hash.

#### v0.3.0 (1 April 2016) ####

- **FIX** Use `:compat` mode when using `Oj` gem to dump/load JSON content.
- **FIX** Prevent unnecessary `Fleck::Request` lock for response reception if the response already received.
- **NEW** Implemented a timeout functionality for asynchronous request, so that if the request isn't completed within that timeout, it will be canceled and removed from
          requests list.
- **NEW** Set `mandatory: true` when publishing the request to RabbitMQ for both `Fleck::Client` and `Fleck::Consumer`, in order to ensure that requests and responses
          are enqueued for sure to RabbitMQ.
- **NEW** Implemented `#pause` and `#resume` methods for `Fleck::Consumer`, that allows to pause the consumer from consuming messages.
- **NEW** `Fleck::Consumer::Response#reject!` support, that allows to reject the processed message. By default `requeue` parameter is set to `false`, so that
          failed requests aren't requeued. You should call `response.reject(requeue: true)` within the `on_message` method, if you want to requeue the processing
          message.

#### v0.2.0 (18 February 2016) ####

- **NEW** `timeout` (synchronous requests only) and `queue` support for `Fleck::Client#request`
- **NEW** Keywords arguments for `Fleck::Client#request` method (ex. `client.request(headers: {h1: v1, ...}, params: {p1: v2, ...}`)
