# frozen_string_literal: true

module Fleck
  module Core
    class Consumer
      # `Decorators` module implements the feature which allows to use decorators for action methods.
      # This will provide a easier and cleaner way to define consumer actions
      module Decorators
        def self.included(base)
          base.extend ClassMethods
          base.send :include, InstanceMethods
        end

        # Defines class methods to import when `Decorators` module is imported.
        module ClassMethods
          def method_added(name)
            super(name)

            # Register method as action `action` or `action_name` decorator has been used
            method_options[:action_name] && register_action(method_options[:action_name], name, method_options)

            # Reset method options after method has been added
            reset_method_options!
          end

          def method_options
            @method_options ||= default_method_options
          end

          def default_method_options
            {
              action_name: nil,
              description: nil,
              params: {}.to_hash_with_indifferent_access,
              headers: {}.to_hash_with_indifferent_access
            }
          end

          def reset_method_options!
            @method_options = nil
          end

          def action(name, description = nil)
            action_name(name)
            desc(description)
          end

          def desc(description)
            method_options[:description] = description if description
          end

          def param(name, modifier = nil, **options)
            method_options[:params][name] = ActionParam.new(name, modifier, **options)
          end

          def header(name, modifier = nil, **options)
            raise 'Not Implemented'
            # method_options[:headers][name] = ActionParam.new(name, options[:type], options)
          end

          protected

          def action_name(name)
            valid = name.is_a?(String) || name.is_a?(Symbol)
            valid or raise(ArgumentError, "Invalid action name type: #{name.class}, String or Symbol expected!")

            method_options[:action_name] = name
          end
        end

        # Defines instance methods to import when `Decorators` module is imported.
        module InstanceMethods
        end
      end
    end
  end
end
