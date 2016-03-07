
module Fleck
  class Client::Request
    include Fleck::Loggable

    attr_reader :id, :response, :completed

    def initialize(client, routing_key, reply_to, headers: {}, params: {}, timeout: nil, &callback)
      @id              = SecureRandom.uuid
      logger.progname += " #{@id}"

      logger.debug "Preparing new request"

      @client      = client
      @routing_key = routing_key
      @reply_to    = reply_to
      @params      = params
      @headers     = headers
      @timeout     = timeout
      @response    = nil
      @lock        = Mutex.new
      @condition   = ConditionVariable.new
      @callback    = callback
      @started_at  = nil
      @ended_at    = nil
      @completed   = false
      @async       = false

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
      @async = async
      data = Oj.dump({
        headers: @headers,
        params:  @params
      }, mode: :compat)
      logger.debug("Sending request with data: #{data}")

      options = { routing_key: @routing_key, reply_to: @reply_to, correlation_id: @id, mandatory: true }
      options[:expiration] = (@timeout * 1000).to_i unless @timeout.nil?

      @client.publish(data, options)

      @lock.synchronize { @condition.wait(@lock) } unless @async
    end

    def complete!
      @completed = true
      @ended_at  = Time.now.to_f
      @lock.synchronize { @condition.signal } unless @async
      logger.debug "Done in #{((@ended_at - @started_at).round(5) * 1000).round(2)} ms"
    end

    def cancel!
      logger.warn "Request canceled!"
      self.response = Fleck::Client::Response.new(Oj.dump({status: 503, errors: ['Service Unavailable'], body: nil} , mode: :compat))
      complete!
    end
  end
end