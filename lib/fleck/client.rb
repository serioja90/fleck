
module Fleck
  class Client
    include Fleck::Loggable

    def initialize(connection, queue_name)
      @connection  = connection
      @queue_name  = queue_name
      @channel     = @connection.create_channel
      @exchange    = @channel.default_exchange
      @reply_queue = @channel.queue("", exclusive: true)
      @requests    = ThreadSafe::Hash.new

      @subscription = @reply_queue.subscribe do |delivery_info, metadata, payload|
        begin
          logger.debug "Response received: #{payload}"
          request = @requests[metadata[:correlation_id]]
          if request
            request.response = Fleck::Client::Response.new(payload)
            request.complete!
            @requests.delete metadata[:correlation_id]
          end
        rescue => e
          logger.error e.inspect + "\n" + e.backtrace.join("\n")
        end
      end

      logger.debug("Client initialized!")

      at_exit do
        terminate
      end
    end

    def request(headers: {}, params: {}, async: false, timeout: nil, queue: @queue_name, &block)
      request = Fleck::Client::Request.new(@exchange, queue, @reply_queue.name, headers, params, &block)
      @requests[request.id] = request
      if timeout && !async
        begin
          Timeout.timeout(timeout.to_f) do
            request.send!(false)
          end
        rescue Timeout::Error => e
          logger.warn "Failed to get any response in #{timeout} seconds for request #{request.id.to_s.color(:red)}! The request will be canceled."
          request.cancel!
          @requests.delete request.id
        end
      else
        request.send!(async)
      end

      return request.response
    end

    def terminate
      logger.info "Unsubscribing from #{@reply_queue.name}"
      @requests.each do |id, request|
        begin
          request.cancel!
        rescue => e
          logger.error e.inspect + "\n" + e.backtrace.join("\n")
        end
      end
      @requests.clear
      @subscription.cancel
    end
  end
end

require "fleck/client/request"
require "fleck/client/response"
