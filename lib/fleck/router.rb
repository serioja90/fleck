$LOAD_PATH.unshift(File.dirname(__FILE__))

module Fleck
  autoload "Subscription", "subscription"

  class Router
    def initialize(config)
      raise ArgumentError.new("Configuration cannot be nil!") if config.nil?
      raise ArgumentError.new("Invalid configuration type!")  unless config.is_a?(Fleck::Config)

      @config = config
      @connections = {}
      @subscriptions = {}
    end

    def route(queue_name, to: nil)
      raise "Invalid queue: #{queue_name.inspect}" unless @config.config.rabbitmq.queue_exists?(queue_name)
      raise "Invalid controller: #{to.inspect}" unless to && (to.is_a?(String) || to.is_a?(Symbol) || to.is_a?(Class))

      register(queue_name, to)
    end

    private

    def register(queue_name, controller)
      app_name = @config.config.app.name
      queue_config = @config.config.rabbitmq.queues[queue_name]
      cluster = queue_config["cluster"]
      @connections[cluster] ||= @config.config.rabbitmq.new_connection(cluster: cluster)
      if @connections[cluster]
        @connections[cluster].start unless @connections[cluster].connected?
        @subscriptions[queue_name] = Fleck::Subscription.new(@connections[cluster], queue_name, queue_config, app_name, controller)
      else
        fail "Unable to register route: invalid RabbitMQ connection!"
      end
    end
  end
end
