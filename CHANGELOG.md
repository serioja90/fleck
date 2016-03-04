# CHANGELOG

## (develop)
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