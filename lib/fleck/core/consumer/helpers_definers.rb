module Fleck
  module Core
    class Consumer
      module HelpersDefiners
        INTERRUPT_NAME = :terminate_execution

        def self.included(base)
          base.extend ClassMethods
          base.send :include, InstanceMethods
        end

        # Defines class methods to import when `HelpersDefilers` module is imported.
        module ClassMethods
          def error_method(name, code, message)
            define_method(name) do |details = nil, interrupt: true|
              response.render_error(code, [message] + [details].flatten)
              throw INTERRUPT_NAME if interrupt
            end
          end

          def redirect_method(name, code)
            success_method(name, code)
          end

          def success_method(name, code)
            define_method(name) do |body = nil, interrupt: true|
              response.status = code
              response.body = body
              throw INTERRUPT_NAME if interrupt
            end
          end

          def information_method(name, code)
            success_method(name, code)
          end
        end

        # Defines instance methods to import when `HelpersDefilers` module is imported.
        module InstanceMethods
        end
      end
    end
  end
end
