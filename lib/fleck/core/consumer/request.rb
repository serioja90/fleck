# frozen_string_literal: true

module Fleck
  module Core
    class Consumer
      class Request
        include Fleck::Loggable

        attr_reader :id, :response, :metadata, :payload, :action, :data, :headers, :version, :ip, :params, :status, :errors,
                    :delivery_tag, :app_id, :reply_to, :created_at, :processed_at

        def initialize(metadata, payload, delivery_info)
          @created_at      = Time.now
          @id              = metadata.correlation_id
          logger.progname += " #{@id}"

          @response      = Fleck::Core::Consumer::Response.new(metadata.correlation_id)
          @metadata      = metadata
          @app_id        = metadata[:app_id]
          @reply_to      = @metadata.reply_to
          @payload       = payload
          @exchange      = delivery_info.exchange.inspect
          @queue         = delivery_info.routing_key.inspect
          @delivery_tag  = delivery_info.delivery_tag
          @data          = {}
          @headers       = (@metadata.headers || {}).to_hash_with_indifferent_access
          @action        = @metadata.type
          @version       = nil
          @ip            = nil
          @params        = {}
          @failed        = false

          parse_request!
        end

        def processed!
          @processed_at = Time.now
        end

        def execution_time
          ((@processed_at.to_f - @created_at.to_f) * 1000).round(2)
        end

        def failed?
          @failed
        end

        protected

        def parse_request!
          @data = Oj.load(@payload, mode: :compat).to_hash_with_indifferent_access.filtered!
          @headers.merge!(@data['headers'] || {}).filtered!

          logger.debug "Processing request (exchange: #{@exchange}, queue: #{@queue}, options: #{@headers}, message: #{@data})"

          @action            ||= @headers['action']
          @headers['action'] ||= @action
          @version             = @headers['version']
          @ip                  = @headers['ip']
          @params              = @data['params'] || {}
        rescue Oj::ParseError => e
          log_error(e)
          response.render_error(400, 'Bad request', e.inspect)
          @failed = true
        rescue StandardError => e
          log_error(e)
          response.render_error(500, 'Internal Server Error', e.inspect)
          @failed = true
        end
      end
    end
  end
end
