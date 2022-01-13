
module Fleck
  module Core
    class Consumer
      class Response
        include Fleck::Loggable

        attr_accessor :id, :status, :errors, :headers, :body

        def initialize(request_id)
          @id = request_id
          logger.progname += " #{@id}"

          @status     = 200
          @errors     = []
          @headers    = {}
          @body       = nil
          @rejected   = false
          @requeue    = false
          @deprecated = false
        end

        def reject!(requeue: false)
          @rejected = true
          @requeue  = requeue
        end

        def rejected?
          @rejected
        end

        def requeue?
          @requeue
        end

        def errors?
          !@errors.empty?
        end

        def deprecated!
          @deprecated = true
        end

        def deprecated?
          @deprecated
        end

        def not_found(msg = nil)
          @status = 404
          @errors << 'Resource Not Found'
          @errors << msg if msg
        end

        def render_error(status, msg = [])
          raise ArgumentError, "Invalid status code: #{status.inspect}" unless (400..599).cover?(status.to_i)

          @status = status.to_i
          if msg.is_a?(Array)
            @errors += msg
          else
            @errors << msg
          end

          @errors.compact!
        end

        def to_json(filter: false)
          data = {
            "status"     => @status,
            "errors"     => @errors,
            "headers"    => @headers,
            "body"       => @body,
            "deprecated" => @deprecated
          }
          data.filter! if filter

          return Oj.dump(data, mode: :compat)
        rescue => e
          logger.error e.inspect + "\n" + e.backtrace.join("\n")
          return Oj.dump({
            "status" => 500,
            "errors" => ['Internal Server Error', 'Failed to dump the response to JSON']
          }, mode: :compat)
        end

        def to_s
          return "#<#{self.class} #{self.to_json(filter: true)}>"
        end
      end
    end
  end
end
