module Fleck
  module Core
    class Consumer
      module Decorators
        def self.included(base)
          base.extend ClassMethods
          base.send :include, InstanceMethods
        end

        # Defines class methods to import when `Decorators` module is imported.
        module ClassMethods
          # TODO: implement the feature for action decorators
          def method_added(name)
            super(name)

            # Save method options to @method_decorators
            method_decorators[name.to_s] = method_options

            # Reset method options after method has been added
            reset_method_options!
          end

          def method_decorators
            @method_decorators ||= {}
          end

          def method_options
            @method_options ||= default_method_options
          end

          def default_method_options
            {
              params: {}.to_hash_with_indifferent_access,
              headers: {}.to_hash_with_indifferent_access,
              description: nil
            }
          end

          def reset_method_options!
            @method_options = nil
          end

          def desc(description)
            method_options[:description] = description
          end

          def param(name, options = {})
            method_options[:params][name] = options
          end

          def header(name, options = {})
            method_options[:headers][name] = options
          end
        end

        # Defines instance methods to import when `Decorators` module is imported.
        module InstanceMethods
        end
      end
    end
  end
end
