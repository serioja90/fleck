
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

      request = Fleck::Client::Request.new(self, queue, @reply_queue.name, action: action, version: version, headers: headers, params: params, timeout: timeout, rmq_options: rmq_options, &block)
      @requests[request.id] = request
      if timeout && !async
        begin
          Timeout.timeout(timeout.to_f) do
            request.send!(false)
          end
        rescue Timeout::Error
          logger.warn "Failed to get any response in #{timeout} seconds for request #{request.id.to_s.color(:red)}! The request will be canceled."
          request.cancel!
          @requests.delete request.id
        end
      elsif timeout && async
        request.send!(async)
        Ztimer.after(timeout * 1000) do |slot|
          if @multiple_responses && !request.response.nil?
            request.complete!
            @requests.delete request.id
          end

          unless request.completed
            logger.warn "TIMEOUT #{request.id} (#{((slot.executed_at - slot.enqueued_at) / 1000.to_f).round(2)} ms)"
            request.cancel!
            @requests.delete request.id
          end
        end
      else
        request.send!(async)
      end

      return request.response
    end

    def publish(data, options)
      return if @terminated
      @mutex.synchronize { @publisher.publish(data, options) }
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
            @requests.delete metadata[:correlation_id]
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
          request = @multiple_responses ? @requests[metadata[:correlation_id]] : @requests.delete(metadata[:correlation_id])
          if request
            request.response = Fleck::Client::Response.new(payload)
            request.complete! unless @multiple_responses
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
