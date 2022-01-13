# frozen_string_literal: true

module Fleck
  module Core
    class Consumer
      module Logger
        def self.included(base)
          base.extend ClassMethods
          base.send :include, InstanceMethods
        end

        # Defines class methods to import when `Logger` module is imported.
        module ClassMethods
          attr_accessor :logger
        end

        # Defines instance methods to import when `Logger` module is imported.
        module InstanceMethods
          def logger
            return @logger if @logger

            @logger = self.class.logger.clone
            @logger.progname = self.class.name.to_s + (configs[:concurrency].to_i <= 1 ? '' : "[#{consumer_id}]")

            @logger
          end

          private

          def log_request
            status = final_response_status
            message = log_formatted_message

            if status >= 500
              logger.error message
            elsif status >= 400 || response.deprecated?
              logger.warn message
            else
              logger.info message
            end
          end

          def exchange_type_code
            rmq_exchange_type.to_s[0].upcase
          end

          def final_response_status
            return 406 if response.rejected?
            return 503 if channel.closed?

            response.status
          end

          def log_formatted_message
            [
              request_origin,
              exchange_and_queue_name,
              request_metadata,
              request_execution_time,
              deprecation_message
            ].join
          end

          def request_origin
            "#{request.ip} #{request.app_id} => "
          end

          def exchange_and_queue_name
            ex_name = rmq_exchange_name.to_s == '' ? ''.inspect : rmq_exchange_name
            "(#{ex_name.to_s.inspect}|#{exchange_type_code}|#{queue_name}) "
          end

          def request_metadata
            "##{request.id} \"#{request.action} /#{request.version || 'v1'}\" #{final_response_status} "
          end

          def request_execution_time
            "(#{request.execution_time}ms)"
          end

          def deprecation_message
            response.deprecated? ? ' DEPRECATED' : ''
          end
        end
      end
    end
  end
end
