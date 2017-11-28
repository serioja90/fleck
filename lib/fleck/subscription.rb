module Fleck
  class Subscription
    def initialize(connection, name, queue_conf, app_name, controller)
      # check connection
      raise ArgumentError.new("Invalid RabbitMQ connection: nil") if connection.nil?
      raise ArgumentError.new("Invalid RabbitMQ connection: invalid class type #{connection.class.name} (Bunny::Session expected)") unless connection.is_a?(Bunny::Session)
      raise ArgumentError.new("Invalid RabbitMQ connection: disconnected") unless connection.connected?

      # check subscription name
      raise ArgumentError.new("Invalid subscription name: #{name.inspect}") if name.nil? || name.to_s.empty?

      # check queue configs
      raise ArgumentError.new("Invalid queue configurations: #{queue_conf.inspect}") unless queue_conf.is_a?(Hash)
      raise ArgumentError.new("Queue configurations cannot be empty: #{queue_conf.inspect}") if queue_conf.empty?

      @connection   = connection
      @name         = name.to_s
      @queue_conf   = queue_conf
      @queue_name   = @queue_conf["name"]
      @consumer_tag = "#{app_name.to_s.gsub(/\W+/,"_").downcase}-#{@name.gsub(/\W+/, "_").downcase}-#{SecureRandom.urlsafe_base64(10)}"
      @queue        = nil
      @workers      = Ztimer.new(concurrency: @queue_conf["threads"])
      @controller   = controller.is_a?(Class) ? controller : Object.const_get(controller)

      @publishers_mutex = Mutex.new

      create_channel
      create_or_get_direct_queue
      subscribe
    end


    def create_channel
      @channel = @connection.create_channel
      @channel.prefetch @queue_conf["threads"]
    end


    # TODO: use a resource pool for publishers management
    def get_publisher(metadata)
      headers = metadata.headers || {}
      exchange_type = headers["exchange_type"] || "direct"
      exchange_name = headers["exchange_name"] || "fleck"

      @publishers_mutex.synchronize do
        @publishers ||= {}
        @publishers[exchange_type] ||= {}
        @publishers[exchange_type][exchange_name] ||= { publisher: Bunny::Exchange.new(@connection.create_channel, :direct, "fleck"), mutex: Mutex.new }
      end

      @publishers[exchange_type][exchange_name][:mutex].synchronize do
        yield @publishers[exchange_type][exchange_name][:publisher]
      end
    end


    def create_or_get_direct_queue
      if @queue_conf["exchange_type"] == "direct" && @queue_conf["exchange_name"] == ""
        # The queue resides on the default exchange, so we'll consume directly from it (no bindings)
        @queue = @channel.queue(@queue_name, auto_delete: false, durable: true)
      else
        # Queue resides on a specific exchange (not default), so we have to bind messages to a direct queue queue
        exchange = Bunny::Exchange.new(@channel, @queue_conf["exchange_type"], @queue_conf["exchange_name"])

        if @queue_conf["consumtion_mode"] == "round-robin"
          direct_queue_name = "_fleck_._.#{exchange.type}.#{exchange.name}.#{@queue_name}"
          @queue = @channel.queue(direct_queue_name, auto_delete: true, durable: true)
        else
          @queue = @channel.queue("", exclusive: true, auto_delete: true)
        end

        @queue.bind(exchange, routing_key: @queue_name)
      end
    end


    def subscribe
      @subscription = @queue.subscribe(manual_ack: true, consumer_tag: @consumer_tag) do |delivery_info, metadata, payload|
        @workers.async do
          response = nil
          begin
            app = @controller.new(delivery_info, metadata, payload)
            response = app.call
          rescue => e
            puts e.to_s + "\n" + e.backtrace.join("\n")
            response = {status: 500, errors: ["Internal Server Error", e.to_s], body: nil, headers: {}, deprecated: false}
          end
          get_publisher(metadata) do |publisher|
            publisher.publish(Oj.dump(response), routing_key: metadata.reply_to, correlation_id: metadata.correlation_id, mandatory: true)
          end
          @channel.ack(delivery_info.delivery_tag)
        end
      end
    end
  end
end