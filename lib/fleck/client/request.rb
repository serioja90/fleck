
module Fleck
  class Client::Request
    include Fleck::Loggable

    attr_reader :id, :response

    def initialize(exchange, routing_key, reply_to, payload = {}, headers = {})
      logger.debug "Preparing new request"

      @id          = SecureRandom.uuid
      @exchange    = exchange
      @routing_key = routing_key
      @reply_to    = reply_to
      @payload     = payload
      @headers     = headers
      @response    = nil
      @lock        = Mutex.new
      @condition   = ConditionVariable.new

      logger.debug "Request prepared"
    end

    def response=(value)
      raise ArgumentError.new("Invalid response type: #{value.class}") unless value.is_a?(Fleck::Client::Response)
      @response = value
    end

    def send!
      data = Oj.dump({
        headers: @headers,
        body:    @payload
      })
      logger.debug("Sending request with data: #{data}")

      @exchange.publish(data, routing_key: @routing_key, reply_to: @reply_to, correlation_id: @id)
      @lock.synchronize { @condition.wait(@lock) }
    end

    def complete!
      @lock.synchronize { @condition.signal }
    end
  end
end