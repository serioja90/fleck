
module Fleck
  class Consumer < Core::ConsumerBase
    require_relative 'consumer/response_helpers'

    autoload :Request, 'fleck/consumer/request.rb'
    autoload :Response, 'fleck/consumer/response.rb'

    def initialize(thread_id = nil)
      super(thread_id)

      @__host          = configs[:host]
      @__port          = configs[:port]
      @__user          = configs.fetch(:user, 'guest')
      @__pass          = configs.fetch(:password, configs[:pass])
      @__vhost         = configs.fetch(:vhost, '/')
      @__exchange_type = configs.fetch(:exchange_type, :direct)
      @__exchange_name = configs.fetch(:exchange_name, '')
      @__queue_name    = configs[:queue]
      @__autostart     = configs[:autostart]
      @__prefetch      = configs.fetch(:prefetch, 100).to_i
      @__mandatory     = !configs[:mandatory].nil?

      instance_eval(&self.class.initialize_block) if self.class.initialize_block

      logger.info "Launching #{self.class.to_s.color(:yellow)} consumer ..."

      start if @__autostart

      at_exit do
        terminate
      end
    end

    def start(block: false)
      connect!
      create_channel!
      subscribe!
      @__lock.synchronize { @__lounger.wait(@__lock) } if block
    end

    def on_message
      method_name = actions[request.action.to_s]
      if method_name
        send(method_name)
      else
        not_found!
      end
    end

    def terminate
      @__lock.synchronize { @__lounger.signal }
      pause

      return if channel.nil? || channel.closed?

      channel.close
      logger.info 'Consumer successfully terminated.'
    end

    def logger
      return @logger if @logger

      @logger = self.class.logger.clone
      @logger.progname = self.class.name.to_s + (configs[:concurrency].to_i <= 1 ? '' : "[#{@__thread_id}]")

      @logger
    end

    def configs
      @configs ||= self.class.configs
    end

    def actions
      @actions ||= self.class.actions_map
    end

    def connection
      @__connection
    end

    def channel
      @__channel
    end

    def queue
      @__queue
    end

    def queue_name
      @__queue_name
    end

    def exchange
      @__exchange
    end

    def exchange_type
      @__exchange_type
    end

    def exchange_name
      @__exchange_name
    end

    def publisher
      @__publisher
    end

    def subscription
      @__subscription
    end

    def pause
      return unless subscription

      cancel_ok = subscription.cancel
      @__consumer_tag = cancel_ok.consumer_tag
    end

    def resume
      subscribe!
    end

    def request=(value)
      @__request = value
    end

    def request
      @__request
    end

    def headers
      request.headers
    end

    def params
      request.params
    end

    def response=(value)
      @__response = value
    end

    def response
      @__response
    end

    def save_start_time!
      @__start_time = Time.now
    end

    def save_end_time!
      @__end_time = Time.now
    end

    def exec_time
      ((@__end_time.to_f - @__start_time.to_f) * 1000).round(2)
    end

    def deprecated!
      logger.warn "DEPRECATION: the method `#{caller_locations(1, 1)[0].label}` is going to be deprecated. " \
                  'Please, consider using a newer version of this method.'
      @__response&.deprecated!
    end

    protected

    def connect!
      @__connection = Fleck.connection(host: @__host, port: @__port, user: @__user, pass: @__pass, vhost: @__vhost)
    end

    def create_channel!
      if @__channel && !@__channel.closed?
        logger.info('Closing the opened channel...')
        @__channel.close
      end

      logger.debug "Creating a new channel for #{self.class.to_s.color(:yellow)} consumer"
      @__channel = @__connection.create_channel
      @__channel.prefetch(@__prefetch) # consume messages in batches
      @__publisher = Bunny::Exchange.new(@__connection.create_channel, :direct, 'fleck')
      if @__exchange_type == :direct && @__exchange_name == ''
        @__queue = @__channel.queue(@__queue_name, auto_delete: false)
      else
        @__exchange = Bunny::Exchange.new(@__channel, @__exchange_type, @__exchange_name)
        @__queue = @__channel.queue('', exclusive: true, auto_delete: true).bind(@__exchange, routing_key: @__queue_name)
      end
    end

    def subscribe!
      logger.debug "Consuming from queue: #{@__queue_name.color(:green)}"

      options = { manual_ack: true }
      options[:consumer_tag] = @__consumer_tag if @__consumer_tag

      @__subscription = @__queue.subscribe(options) do |delivery_info, metadata, payload|
        save_start_time!

        self.response = Fleck::Consumer::Response.new(metadata.correlation_id)
        begin
          self.request = Fleck::Consumer::Request.new(metadata, payload, delivery_info)
          if request.errors.empty?
            on_message
          else
            response.status = request.status
            response.errors += request.errors
          end
        rescue StandardError => e
          logger.error "#{e.inspect}\n#{e.backtrace.join("\n")}"
          response.status = 500
          response.errors << 'Internal Server Error'
        end

        if response.rejected?
          channel.reject(delivery_info.delivery_tag, response.requeue?)
        else
          logger.debug "Sending response: #{response}"
          if channel.closed?
            logger.warn "Channel already closed! The response #{request.id} is going to be dropped."
          else
            publisher.publish(
              response.to_json,
              routing_key: metadata.reply_to,
              correlation_id: request.id,
              mandatory: @__mandatory
            )
            channel.ack(delivery_info.delivery_tag)
          end
        end

        save_end_time!
        log_request!
      end
    end

    def log_request!
      ex_type    = @__exchange_type.to_s[0].upcase
      ex_name    = @__exchange_name.to_s == '' ? ''.inspect : @__exchange_name
      status     = response.status
      status     = 406 if response.rejected?
      status     = 503 if channel.closed?

      message = "#{request.ip} #{request.app_id} => " \
                "(#{ex_name.to_s.inspect}|#{ex_type}|#{queue_name}) " \
                "##{request.id} \"#{request.action} /#{request.version || 'v1'}\" #{status} " \
                "(#{exec_time}ms) #{'DEPRECATED!' if response.deprecated?}"

      if status >= 500
        logger.error message
      elsif status >= 400 || response.deprecated?
        logger.warn message
      else
        logger.info message
      end
    end

    def restart!
      create_channel!
      subscribe!
    end
  end
end
