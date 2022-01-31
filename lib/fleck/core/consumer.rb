# frozen_string_literal: true

$LOAD_PATH << File.expand_path(__dir__)

module Fleck
  module Core
    # `Fleck::Core::Consumer` implements the core functionality for `Fleck::Consumer`,
    # so that new `Fleck::Consumers` can be easily created by using inheritance.
    class Consumer
      autoload :Base, 'consumer/base.rb'
      autoload :Actions, 'consumer/actions.rb'
      autoload :Configuration, 'consumer/configuration.rb'
      autoload :Decorators, 'consumer/decorators.rb'
      autoload :HelpersDefiners, 'consumer/helpers_definers.rb'
      autoload :Logger, 'consumer/logger.rb'

      autoload :Request, 'consumer/request.rb'
      autoload :Response, 'consumer/response.rb'

      autoload :ActionHeader, 'consumer/action_header.rb'
      autoload :ActionParam, 'consumer/action_param.rb'
      autoload :Validation, 'consumer/validation.rb'

      include Fleck::Loggable
      include Logger
      include Actions
      include Configuration
      include Decorators
      include HelpersDefiners
      include Base

      require_relative 'consumer/response_helpers'

      attr_accessor :connection, :channel, :queue, :publisher, :consumer_tag, :request, :subscription, :exchange,
                    :consumer_id

      def initialize(consumer_id = nil)
        self.consumer_id = consumer_id

        instance_eval(&self.class.initialize_block) if self.class.initialize_block

        start if autostart?

        at_exit do
          terminate
        end
      end

      def pause
        return if subscription.nil? || channel.nil? || channel.closed?

        cancel_ok = subscription.cancel
        self.consumer_tag = cancel_ok.consumer_tag
      end

      def resume
        subscribe!
      end

      def headers
        request.headers
      end

      def params
        request.params
      end

      def response
        request.response
      end

      def deprecated!
        logger.warn "DEPRECATION: the method `#{caller_locations(1, 1)[0].label}` is going to be deprecated. " \
                    'Please, consider using a newer version of this method.'
        response&.deprecated!
      end

      protected

      def connect!
        self.connection = Fleck.connection(
          host: rmq_host,
          port: rmq_port,
          user: rmq_user,
          pass: rmq_pass,
          vhost: rmq_vhost
        )
      end

      def create_channel!
        if channel && !channel.closed?
          logger.info('Closing the opened channel...')
          channel.close
        end

        logger.debug "Creating a new channel for #{self.class.to_s.color(:yellow)} consumer"
        self.channel = connection.create_channel
        channel.prefetch(prefetch_size) # consume messages in batches
        self.publisher = Bunny::Exchange.new(connection.create_channel, :direct, 'fleck')
        if rmq_exchange_type == :direct && rmq_exchange_name == ''
          self.queue = channel.queue(queue_name, auto_delete: false)
        else
          self.exchange = Bunny::Exchange.new(channel, rmq_exchange_type, rmq_exchange_name)
          self.queue = channel.queue('', exclusive: true, auto_delete: true).bind(exchange, routing_key: queue_name)
        end
      end

      def subscribe!
        logger.debug "Consuming from queue: #{queue_name.color(:green)}"

        options = { manual_ack: true }
        options[:consumer_tag] = consumer_tag if consumer_tag

        self.subscription = queue.subscribe(options) do |delivery_info, metadata, payload|
          process_request!(metadata, payload, delivery_info)
        end
      end

      def process_request!(metadata, payload, delivery_info)
        self.request = Request.new(metadata, payload, delivery_info)

        catch(INTERRUPT_NAME) do
          execute_action! unless request.failed?
        end
      rescue StandardError => e
        log_error(e)
        internal_server_error! e.inspect, interrupt: false
      ensure
        send_response!
        log_request
      end

      def send_response!
        return reject_request! if request.rejected?

        logger.debug "Sending response: #{response}"

        if channel.closed?
          return logger.warn "Channel already closed! The response #{request.id} is going to be dropped."
        end

        publish_response!
        request.processed!
      end

      def reject_request!
        channel.reject(request.delivery_tag, request.requeue?)
      end

      def publish_response!
        publisher.publish(
          response.to_json,
          routing_key: request.reply_to,
          correlation_id: request.id,
          mandatory: ack_mandatory?
        )
        channel.ack(request.delivery_tag)
      end

      def restart!
        create_channel!
        subscribe!
      end
    end
  end
end
