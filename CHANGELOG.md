# CHANGELOG

## (develop) ##
  - **NEW** `Fleck::Consumer::Response#reject!` support, that allows to reject the processed message. By default `requeue` parameter is set to `false`, so that
            failed requests aren't requeued. You should call `response.reject(requeue: true)` within the `on_message` method, if you want to requeue the processing
            message.

## v0.2.0 (18 February 2016)
  - **NEW** `timeout` (synchronous requests only) and `queue` support for `Fleck::Client#request`
  - **NEW** keywords arguments for `Fleck::Client#request` method (ex. `client.request(headers: {h1: v1, ...}, params: {p1: v2, ...}`)