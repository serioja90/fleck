# frozen_string_literal: true

module Fleck
  module Core
    class Consumer
      # Base methods for consumer setup, start and termination.
      module Base
        def self.included(base)
          base.extend ClassMethods
          base.send :include, InstanceMethods
        end

        # Defines class methods to import when `Autostart` module is imported.
        module ClassMethods
          attr_accessor :consumers, :initialize_block, :lock, :condition

          def inherited(subclass)
            super
            return if subclass == Fleck::Consumer

            init_consumer(subclass)
            autostart(subclass)
            Fleck.register_consumer(subclass)
          end

          def initialize(&block)
            self.initialize_block = block
          end

          def start(block: false)
            consumers.each(&:start)
            wait_termination if block
          end

          def wait_termination
            lock.synchronize { condition.wait(lock) }
          end

          def on_terminate(consumer)
            consumers.delete consumer
            terminate if consumers.empty?
          end

          def terminate
            consumers.each(&:terminate)
            lock.synchronize { condition.signal }
          end

          protected

          def init_consumer(subclass)
            configure_logger(subclass)

            subclass.lock = Mutex.new
            subclass.condition = ConditionVariable.new

            subclass.configs = Fleck.config.default_options
            subclass.actions_map = {}
            subclass.consumers   = []
          end

          def configure_logger(subclass)
            subclass.logger          = Fleck.logger.clone
            subclass.logger.progname = subclass.to_s
            subclass.logger.debug "Setting defaults for #{subclass.to_s.color(:yellow)} consumer"
          end

          def autostart(subclass)
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
        end

        # Defines instance methods to import when `Autostart` module is imported.
        module InstanceMethods
          def autostart?
            configs[:autostart].nil? || configs[:autostart]
          end

          def start
            logger.info "Launching #{self.class.to_s.color(:yellow)} consumer ..."
            connect!
            create_channel!
            subscribe!
          end

          def terminate
            pause

            return if channel.nil? || channel.closed?

            channel.close

            logger.info 'Consumer successfully terminated.'
            self.class.on_terminate(self)
          end
        end
      end
    end
  end
end
