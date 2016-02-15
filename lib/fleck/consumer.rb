
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
      @thread_id    = thread_id
      @connection   = nil

      @host       = configs[:host]
      @port       = configs[:port]
      @user       = configs[:user]     || 'guest'
      @pass       = configs[:password] || configs[:pass]
      @vhost      = configs[:vhost]    || "/"
      @queue_name = configs[:queue]

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
      unless @channel.closed?
        @channel.close
        logger.info "Consumer successfully terminated."
      end
    end

    def logger
      return @logger if @logger
      @logger = self.class.logger.clone
      @logger.progname = "#{self.class.name}" + (configs[:concurrency].to_i <= 1 ? "" : "[#{@thread_id}]")

      @logger
    end

    def configs
      @configs ||= self.class.configs
    end

    protected

    def connect!
      @connection = Fleck.connection(host: @host, port: @port, user: @user, pass: @pass, vhost: @vhost)
    end

    def create_channel!
      if @channel && !@channel.closed?
        logger.info("Closing the opened channel...")
        @channel.close
      end

      logger.debug "Creating a new channel for #{self.class.to_s.color(:yellow)} consumer"
      @channel  = @connection.create_channel
      @channel.prefetch(1) # prevent from dispatching a new RabbitMQ message, until the previous message is not processed
      @queue    = @channel.queue(@queue_name, auto_delete: false)
      @exchange = @channel.default_exchange
    end

    def subscribe!
      logger.debug "Consuming from queue: #{@queue_name.color(:green)}"
      @subscription = @queue.subscribe do |delivery_info, metadata, payload|
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

        logger.debug "Sending response: #{response}"
        @exchange.publish(response.to_json, routing_key: metadata.reply_to, correlation_id: metadata.correlation_id)
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