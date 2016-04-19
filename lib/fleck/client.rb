
module Fleck
  class Client
    include Fleck::Loggable

    def initialize(connection, queue_name = "", exchange_type: :direct, exchange_name: "", multiple_responses: false, concurrency: 1)
      @connection         = connection
      @queue_name         = queue_name
      @multiple_responses = multiple_responses
      @default_timeout    = multiple_responses ? 60 : nil
      @concurrency        = [concurrency.to_i, 1].max
      @requests           = ThreadSafe::Hash.new
      @subscriptions      = ThreadSafe::Array.new
      @terminated         = false
      @mutex              = Mutex.new

      @channel     = @connection.create_channel
      @exchange    = @channel.default_exchange
      @publisher   = Bunny::Exchange.new(@channel, exchange_type, exchange_name)
      @reply_queue = @channel.queue("", exclusive: true, auto_delete: true)

      handle_returned_messages!
      @concurrency.times { handle_responses! }

      logger.debug("Client initialized!")

      at_exit do
        terminate
      end
    end

    def request(action: nil, version: nil, headers: {}, params: {}, async: @multiple_responses || false, timeout: @default_timeout, queue: @queue_name, rmq_options: {}, &block)

      if @terminated
        return Fleck::Client::Response.new(Oj.dump({status: 503, errors: ['Service Unavailable'], body: nil} , mode: :compat))
      end

      request = Fleck::Client::Request.new(
        self, queue, @reply_queue.name,
        action:             action,
        version:            version,
        headers:            headers,
        params:             params,
        timeout:            timeout,
        multiple_responses: @multiple_responses,
        rmq_options:        rmq_options,
        &block
      )

      @requests[request.id] = request
      request.send!(async)

      return request.response
    end


    def publish(data, options)
      return if @terminated
      @mutex.synchronize { @publisher.publish(data, options) }
    end


    def remove_request(request_id)
      @requests.delete request_id
    end


    def terminate
      @terminated = true
      logger.info "Unsubscribing from #{@reply_queue.name}"
      @subscriptions.map(&:cancel) # stop receiving new messages
      logger.info "Canceling pending requests"
      # cancel pending requests
      while item = @requests.shift do
        begin
          item[1].cancel!
        rescue => e
          logger.error e.inspect + "\n" + e.backtrace.join("\n")
        end
      end
    end


    protected

    def handle_returned_messages!
      @exchange.on_return do |return_info, metadata, content|
        begin
          logger.warn "Request #{metadata[:correlation_id]} returned"
          request = @requests[metadata[:correlation_id]]
          if request
            request.cancel!
          end
        rescue => e
          logger.error e.inspect + "\n" + e.backtrace.join("\n")
        end
      end
    end

    def handle_responses!
      @subscriptions << @reply_queue.subscribe do |delivery_info, metadata, payload|
        begin
          logger.debug "Response received: #{payload}"
          request = @requests[metadata[:correlation_id]]
          if request
            request.response = Fleck::Client::Response.new(payload)
          else
            logger.warn "Request #{metadata[:correlation_id]} not found!"
          end
        rescue => e
          logger.error e.inspect + "\n" + e.backtrace.join("\n")
        end
      end
    end
  end
end

require "fleck/client/request"
require "fleck/client/response"
