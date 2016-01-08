
module Fleck
  class Consumer
    class << self
      attr_accessor :logger, :configs, :consumers
    end

    def self.inherited(subclass)
      super
      init_consumer(subclass)

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

    def initialize(thread_id)
      @thread_id    = thread_id
      @delivery_tag = nil

      @host       = configs[:host]
      @port       = configs[:port]
      @user       = configs[:user]     || 'guest'
      @pass       = configs[:password] || configs[:pass]
      @vhost      = configs[:vhost]    || "/"
      @queue_name = configs[:queue]

      logger.info "Launching #{self.class.to_s.color(:yellow)} consumer ..."
      logger.info "Connecting to #{@host}:#{@port}#{@vhost} as #{@user}"
      @connection = Bunny.new(host: @host, port: @port, user: @user, pass: @pass, vhost: @vhost)
      @connection.start

      logger.debug "Creating a new channel for #{self.class.to_s.color(:yellow)} consumer"
      @channel = @connection.create_channel
      @channel.prefetch(1) # prevent from dispatching a new RabbitMQ message, until the previous message is not processed
      @queue   = @channel.queue(@queue_name, auto_delete: false)

      logger.debug "Consuming from queue: #{@queue_name.color(:green)}"
      consumer = self
      @thread = Thread.new do
        @subscription = @queue.subscribe(manual_ack: true, block: true) do |delivery_info, metadata, payload|
          @delivery_tag = delivery_info.delivery_tag
          on_message(delivery_info, metadata, payload)
          @channel.ack(@delivery_tag)
        end
      end
      @thread.abort_on_exception = true

      at_exit do
        terminate
      end
    end

    def on_message(delivery_info, metadata, payload)
      raise NotImplementedError.new("(#{self.class}) You must implement #on_message(delivery_info, metadata, payload) method.")
    end

    def terminate
      @channel.close unless @channel.closed?
      logger.info "Consumer successfully terminated."
    end

    def logger
      return @logger if @logger
      @logger = self.class.logger.clone
      @logger.progname = "#{self.class.name}[#{@thread_id}]"

      @logger
    end

    def configs
      @configs ||= self.class.configs
    end
  end
end