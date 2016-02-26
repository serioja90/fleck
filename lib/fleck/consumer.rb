
module Fleck
  class Consumer
    class << self
      attr_accessor :logger, :configs, :consumers
    end

    def self.inherited(subclass)
      super
      init_consumer(subclass)
      autostart(subclass)
      Fleck.register_consumer(subclass)
    end

    def self.configure(opts = {})
      self.configs.merge!(opts)
      logger.debug "Consumer configurations updated."
    end

    def self.init_consumer(subclass)
      subclass.logger          = Fleck.logger.clone
      subclass.logger.progname = subclass.to_s

      subclass.logger.debug "Setting defaults for #{subclass.to_s.color(:yellow)} consumer"

      subclass.configs   = Fleck.config.default_options
      subclass.consumers = []
    end

    def self.autostart(subclass)
      # Use TracePoint to autostart the consumer when ready
      trace = TracePoint.new(:end) do |tp|
        if tp.self == subclass
          # disable tracing when we reach the end of the subclass
          trace.disable
          # create a new instance of the subclass, in order to start the consumer
          [subclass.configs[:concurrency].to_i, 1].max.times do |i|
            subclass.consumers << subclass.new(i)
          end
        end
      end
      trace.enable
    end

    def initialize(thread_id = nil)
      @__thread_id    = thread_id
      @__connection   = nil

      @__host       = configs[:host]
      @__port       = configs[:port]
      @__user       = configs[:user]     || 'guest'
      @__pass       = configs[:password] || configs[:pass]
      @__vhost      = configs[:vhost]    || "/"
      @__queue_name = configs[:queue]

      logger.info "Launching #{self.class.to_s.color(:yellow)} consumer ..."

      connect!
      create_channel!
      subscribe!

      at_exit do
        terminate
      end
    end

    def on_message(request, response)
      raise NotImplementedError.new("You must implement #on_message(delivery_info, metadata, payload) method")
    end

    def terminate
      unless @__channel.closed?
        @__channel.close
        logger.info "Consumer successfully terminated."
      end
    end

    def logger
      return @logger if @logger
      @logger = self.class.logger.clone
      @logger.progname = "#{self.class.name}" + (configs[:concurrency].to_i <= 1 ? "" : "[#{@__thread_id}]")

      @logger
    end

    def configs
      @configs ||= self.class.configs
    end

    def connection
      return @__connection
    end

    def channel
      return @__channel
    end

    def queue
      return @__queue
    end

    def exchange
      return @__exchange
    end

    def subscription
      return @__subscription
    end

    protected

    def connect!
      @__connection = Fleck.connection(host: @__host, port: @__port, user: @__user, pass: @__pass, vhost: @__vhost)
    end

    def create_channel!
      if @__channel && !@__channel.closed?
        logger.info("Closing the opened channel...")
        @__channel.close
      end

      logger.debug "Creating a new channel for #{self.class.to_s.color(:yellow)} consumer"
      @__channel  = @__connection.create_channel
      @__channel.prefetch(1) # prevent from dispatching a new RabbitMQ message, until the previous message is not processed
      @__queue    = @__channel.queue(@__queue_name, auto_delete: false)
      @__exchange = @__channel.default_exchange
    end

    def subscribe!
      logger.debug "Consuming from queue: #{@__queue_name.color(:green)}"
      @__subscription = @__queue.subscribe(manual_ack: true) do |delivery_info, metadata, payload|
        response = Fleck::Consumer::Response.new(metadata.correlation_id)
        begin
          request  = Fleck::Consumer::Request.new(metadata, payload)
          if request.errors.empty?
            on_message(request, response)
          else
            response.status = request.status
            response.errors += request.errors
          end
        rescue => e
          logger.error e.inspect + "\n" + e.backtrace.join("\n")
          response.status = 500
          response.errors << 'Internal Server Error'
        end

        if response.rejected?
          # the request was rejected, so we have to notify the reject
          logger.warn "Request #{response.id} was rejected!"
          @__channel.reject(delivery_info.delivery_tag, response.requeue?)
        else
          logger.debug "Sending response: #{response}"
          @__exchange.publish(response.to_json, routing_key: metadata.reply_to, correlation_id: metadata.correlation_id)
          @__channel.ack(delivery_info.delivery_tag)
        end
      end
    end

    def restart!
      create_channel!
      subscribe!
    end
  end
end

require "fleck/consumer/request"
require "fleck/consumer/response"