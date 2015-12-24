
module Fleck
  class Consumer
    class << self
      attr_accessor :logger, :configs
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
          (subclass.configs[:threads] || 1).times do
            subclass.new
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
      subclass.logger = Fleck.logger.clone
      subclass.logger.progname = subclass.to_s
      subclass.logger.debug "Setting defaults for #{subclass.to_s.color(:yellow)} consumer"
      subclass.configs = Fleck.config.default_options
    end

    def initialize
      logger.info "Launching #{self.class.to_s.color(:yellow)} consumer ..."
      @host       = configs[:host]
      @port       = configs[:port]
      @user       = configs[:user]     || 'guest'
      @pass       = configs[:password] || configs[:pass]
      @vhost      = configs[:vhost]    || "/"
      @queue_name = configs[:queue] 

      logger.info "Connecting to #{@host}:#{@port}#{@vhost} as #{@user}"
      @connection = Bunny.new(host: @host, port: @port, user: @user, pass: @pass, vhost: @vhost)
      @connection.start

      logger.debug "Creating a new channel for #{self.class.to_s.color(:yellow)} consumer"
      @channel = @connection.create_channel
      @queue   = @channel.queue(@queue_name, auto_delete: false)

      logger.debug "Consuming from queue: #{@queue_name.color(:green)}"
      consumer = self
      Celluloid::Future.new do
        @queue.subscribe do |delivery_info, metadata, payload|
          on_message(delivery_info, metadata, payload)
        end
      end
    end

    def on_message(delivery_info, metadata, payload)
      logger.warn "Message received: #{payload}. The message is going to be lost. " +
                  "Please, overwrite the " + "#on_message(delivery_info, metadata, payload) ".color(:green) +
                  "method, if you want to process this message, or simply leave the method empty to " +
                  "supress this message."
    end

    def logger
      @logger ||= self.class.logger
    end

    def configs
      @configs ||= self.class.configs
    end
  end
end