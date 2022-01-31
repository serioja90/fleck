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

          def register_action(action, method_name, options = {})
            if Fleck::Consumer.instance_methods.include?(method_name.to_s.to_sym)
              raise ArgumentError, "Cannot use `:#{method_name}` method as an action, " \
                                    'because it is reserved for Fleck::Consumer internal stuff!'
            end

            options[:method_name] = method_name.to_s
            options[:params] ||= {}
            actions_map[action.to_s] = options
          end
        end

        # Defines instance methods to import when `Actions` module is imported.
        module InstanceMethods
          def actions
            @actions ||= self.class.actions_map
          end

          protected

          def execute_action!
            action_name = request.action.to_s
            action = actions[action_name]
            unless action
              message = "Action #{action_name.inspect} not found!"
              not_found! error: message, body: [
                { type: 'action', name: action_name, value: action_name, error: 'not_found', message: message }
              ]
            end

            # iterate over action params and use param options to validate incoming request params.
            action[:params].each { |_, param| validate_action_param!(param) }

            send(action[:method_name])
          end

          def validate_action_param!(param)
            validation = param.validate(request.params[param.name])
            unless validation.valid?
              bad_request! error: "Invalid param value: #{param.name} = #{validation.value.inspect}",
                           body: validation.errors
            end
            request.params[param.name] = validation.value
          end
        end
      end
    end
  end
end
