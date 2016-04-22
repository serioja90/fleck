# CHANGELOG #

## develop ##
  - **NEW** Added a filter that prevents from using reserved `Fleck::Consumer` methods as actions.
  - **NEW** Implemented the feature that allows to start consumer in a blocking way.
  - **NEW** Added `:prefetch` and `:mandatory` options to `Fleck::Consumer` configuration options.

## v0.5.1 (20 April 2016)
  - **FIX** Don't expire requests with multiple responses if any response is received. Treat that kind of request as expired if no response has been received
            until the request expiration.

## v0.5.0 (20 April 2016) ##
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

## v0.4.1 (18 April 2016) ##
  - **FIX** Fixed a bug of `Fleck::Consumer::Request` class, that was causing errors when RabbitMQ message header wasn't set.

## v0.4.0 (15 April 2016) ##
  - **NEW** Support different types of exchanges in both `Fleck::Client` and `Fleck::Consumer`.
  - **FIX** Use `auto_delete` queue for `Fleck::Client`, so that it is deleted when the client is terminated.
  - **NEW** Add `:rmq_options` option to `Fleck::Client::Request`, which can be used to pass options like `:persistent`, `mandatory`, etc. 
            to RabbitMQ message on publish.
  - **NEW** Store `:headers` attribute of `Fleck::Client::Request` into RabbitMQ message `:headers`, so that in the future only
            `:params` option will be converted to JSON.
  - **NEW** Add `:action` option to `Fleck::Client::Request`, which will replace the action passed within `:headers` hash.

## v0.3.0 (1 April 2016)
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

## v0.2.0 (18 February 2016)
  - **NEW** `timeout` (synchronous requests only) and `queue` support for `Fleck::Client#request`
  - **NEW** Keywords arguments for `Fleck::Client#request` method (ex. `client.request(headers: {h1: v1, ...}, params: {p1: v2, ...}`)