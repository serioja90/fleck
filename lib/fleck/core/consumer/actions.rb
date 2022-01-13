# frozen_string_literal: true

module Fleck
  module Core
    class Consumer
      # `Fleck::Core::Consumer::Actions` module implements the logic for consumer actions
      # registration, so that this information could be used when a request is received.
      # This mechanism will allow to process the request with the appropriate consumer method.
      module Actions
        def self.included(base)
          base.extend ClassMethods
          base.send :include, InstanceMethods
        end

        # Defines class methods to import when `Actions` module is imported.
        module ClassMethods
          attr_accessor :actions_map

          def actions(*args)
            args.each do |item|
              case item
              when Hash then item.each { |k, v| register_action(k.to_s, v.to_s) }
              else register_action(item.to_s, item.to_s)
              end
            end
          end

          def register_action(action, method_name)
            if Fleck::Consumer.instance_methods.include?(method_name.to_s.to_sym)
              raise ArgumentError, "Cannot use `:#{method_name}` method as an action, " \
                                    'because it is reserved for Fleck::Consumer internal stuff!'
            end

            actions_map[action.to_s] = method_name.to_s
          end
        end

        # Defines instance methods to import when `Actions` module is imported.
        module InstanceMethods
          def actions
            @actions ||= self.class.actions_map
          end
        end
      end
    end
  end
end
