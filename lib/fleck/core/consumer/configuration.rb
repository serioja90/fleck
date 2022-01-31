module Fleck
  module Core
    class Consumer
      module Configuration
        def self.included(base)
          base.extend ClassMethods
          base.send :include, InstanceMethods
        end

        # Defines class methods to import when `Configuration` module is imported.
        module ClassMethods
          attr_accessor :configs

          def configure(opts = {})
            configs.merge!(opts)
            logger.debug 'Consumer configurations updated.'
          end
        end

        # Defines instance methods to import when `Configuration` module is imported.
        module InstanceMethods
          def configs
            @configs ||= self.class.configs
          end

          def rmq_host
            @rmq_host ||= configs[:host]
          end

          def rmq_port
            @rmq_port ||= configs[:port]
          end

          def rmq_user
            @rmq_user ||= configs.fetch(:user, 'guest')
          end

          def rmq_pass
            @rmq_pass ||= configs.fetch(:password, configs[:pass])
          end

          def rmq_vhost
            @rmq_vhost ||= configs.fetch(:vhost, '/')
          end

          def queue_name
            @queue_name ||= configs[:queue]
          end

          def rmq_exchange_type
            @rmq_exchange_type ||= configs.fetch(:exchange_type, :direct)
          end

          def rmq_exchange_name
            @rmq_exchange_name ||= configs.fetch(:exchange_name, '')
          end

          def ack_mandatory?
            @ack_mandatory ||= !configs[:mandatory].nil?
          end

          def prefetch_size
            @prefetch_size ||= configs.fetch(:prefetch, 100).to_i
          end
        end
      end
    end
  end
end
