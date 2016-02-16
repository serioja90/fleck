
module Fleck
  class Client::Request
    include Fleck::Loggable

    attr_reader :id, :response

    def initialize(exchange, routing_key, reply_to, headers = {}, params = {}, &callback)
      @id              = SecureRandom.uuid
      logger.progname += " #{@id}"

      logger.debug "Preparing new request"

      @exchange    = exchange
      @routing_key = routing_key
      @reply_to    = reply_to
      @params      = params
      @headers     = headers
      @response    = nil
      @lock        = Mutex.new
      @condition   = ConditionVariable.new
      @callback    = callback
      @started_at  = nil
      @ended_at    = nil

      logger.debug "Request prepared"
    end

    def response=(value)
      logger.debug "Response: #{value.inspect}"
      raise ArgumentError.new("Invalid response type: #{value.class}") unless value.is_a?(Fleck::Client::Response)
      @response = value
      @callback.call(self, value) if @callback
      return value
    end

    def send!(async = false)
      @started_at = Time.now.to_f
      data = Oj.dump({
        headers: @headers,
        params:  @params
      }, mode: :compat)
      logger.debug("Sending request with data: #{data}")

      @exchange.publish(data, routing_key: @routing_key, reply_to: @reply_to, correlation_id: @id)
      @lock.synchronize { @condition.wait(@lock) } unless async
    end

    def complete!
      @lock.synchronize { @condition.signal }
      @ended_at = Time.now.to_f
      logger.debug "Done in #{((@ended_at - @started_at).round(5) * 1000).round(2)} ms"
    end

    def cancel!
      logger.warn "Request canceled!"
      self.response = Fleck::Client::Response.new(Oj.dump({status: 503, errors: ['Service Unavailable'], body: nil} , mode: :compat))
      complete!
    end
  end
end