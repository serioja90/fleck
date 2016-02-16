
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

      @reply_queue.subscribe do |delivery_info, metadata, payload|
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

    def request(headers = {}, payload = {}, async = false, &block)
      request = Fleck::Client::Request.new(@exchange, @queue_name, @reply_queue.name, headers, payload, &block)
      @requests[request.id] = request
      request.send!(async)

      return request.response
    end

    def terminate
      @requests.each do |id, request|
        begin
          request.complete!
        rescue => e
          logger.error e.inspect + "\n" + e.backtrace.join("\n")
        end
      end
    end
  end
end

require "fleck/client/request"
require "fleck/client/response"
