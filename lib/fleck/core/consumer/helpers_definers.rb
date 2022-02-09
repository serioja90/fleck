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
            define_method(name) do |error: nil, body: nil, interrupt: true|
              response.render_error(code, [message] + [error].flatten)
              response.body = body
              throw INTERRUPT_NAME if interrupt
            end
          end

          def redirect_method(name, code)
            success_method(name, code)
          end

          def success_method(name, code)
            define_method(name) do |*args|
              interrupt = (args[1] ? args[1][:interrupt] : true)
              response.status = code
              response.body = args[0]
              throw INTERRUPT_NAME if interrupt
            end
          end

          def information_method(name, code)
            success_method(name, code)
          end
        end

        # Defines instance methods to import when `HelpersDefilers` module is imported.
        module InstanceMethods
          def halt(code, body = nil, errors = nil)
            response.body = body
            if code >= 400
              response.render_error(code, [errors].flatten)
            else
              response.status = code
            end

            throw INTERRUPT_NAME
          end
        end
      end
    end
  end
end
