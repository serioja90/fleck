
module Fleck
  class Client::Request
    include Fleck::Loggable

    attr_reader :id, :response, :completed, :expired

    def initialize(client, routing_key, reply_to, action: nil, version: nil, headers: {}, params: {}, timeout: nil, multiple_responses: false, rmq_options: {}, &callback)
      @id              = SecureRandom.uuid
      logger.progname += " #{@id}"

      logger.debug "Preparing new request"

      @client             = client
      @response           = nil
      @lock               = Mutex.new
      @condition          = ConditionVariable.new
      @callback           = callback
      @started_at         = nil
      @ended_at           = nil
      @completed          = false
      @async              = false
      @action             = action  || headers[:action]  || headers['action']
      @version            = version || headers[:version] || headers['version']
      @routing_key        = routing_key
      @timeout            = (timeout * 1000).to_i unless timeout.nil?
      @multiple_responses = multiple_responses
      @ztimer_slot        = nil
      @expired            = false

      headers[:version] = @version
      headers[:ip]      = @client.local_ip

      @options = {
        routing_key:      @routing_key,
        reply_to:         reply_to,
        correlation_id:   @id,
        type:             action,
        headers:          headers,
        mandatory:        rmq_options[:mandatory]  || true,
        persistent:       rmq_options[:persistent] || false,
        content_type:     'application/json',
        content_encoding: 'UTF-8'
      }
      @options[:priority]   = rmq_options[:priority] unless rmq_options[:priority].nil?
      @options[:app_id]     = rmq_options[:app_id] || Fleck.config.app_name
      @options[:expiration] = @timeout

      @message = Oj.dump({headers: headers, params: params}, mode: :compat)

      logger.debug "Request prepared"
    end

    def response=(value)
      logger.debug "Response: #{value.inspect}"
      raise ArgumentError.new("Invalid response type: #{value.class}") unless value.is_a?(Fleck::Client::Response)
      @response = value
      deprecated! if @response.deprecated?
      @callback.call(self, value) if @callback
      complete! unless @multiple_responses
      return value
    end

    def send!(async = false)
      @started_at = Time.now.to_f
      @async = async
      logger.debug("Sending request with (options: #{@options}, message: #{@message})")

      if @timeout
        @ztimer_slot = Ztimer.after(@timeout){ expire! }
      end

      @client.publish(@message, @options)

      @lock.synchronize do
        unless @async || @completed
          logger.debug("Waiting for response")
          @condition.wait(@lock)
          logger.debug("Request terminated.")
        end
      end
    end

    def complete!
      @ztimer_slot.cancel! if @ztimer_slot
      @lock.synchronize do
        @completed = true
        @ended_at  = Time.now.to_f
        logger.debug "Done #{@async ? 'async' : 'synchronized'} in #{((@ended_at - @started_at).round(5) * 1000).round(2)} ms"
        @condition.signal unless @async
        @client.remove_request(@id)
      end
    end

    def cancel!
      logger.warn "Request canceled!"
      self.response = Fleck::Client::Response.new(Oj.dump({status: 503, errors: ['Service Unavailable'], body: nil} , mode: :compat))
    end

    def expire!
      if @multiple_responses
        if @response.nil?
          @expired = true
          cancel!
        else
          complete!
        end
      elsif !@completed
        @expired = true
        cancel!
      end
    end

    def expired?
      return @expired
    end

    protected

    def deprecated!
      logger.warn("DEPRECATION: the method `#{@action}` of version '#{@version.inspect}' on queue '#{@routing_key}' is going to be deprecated. Please, consider using a newer version of this method.")
    end
  end
end