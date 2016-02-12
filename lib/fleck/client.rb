
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
        logger.debug "Response received: #{payload}"
        request = @requests[metadata[:correlation_id]]
        if request
          request.response = Fleck::Client::Response.new(payload)
          request.complete!
          @requests.delete metadata[:correlation_id]
        end
      end

      logger.debug("Client initialized!")
    end

    def request(payload, async = false, &block)
      request = Fleck::Client::Request.new(@exchange, @queue_name, @reply_queue.name, payload, &block)
      @requests[request.id] = request
      request.send!(async)

      return request.response
    end
  end
end

require "fleck/client/request"
require "fleck/client/response"
