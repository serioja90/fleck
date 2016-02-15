
module Fleck
  class Consumer::Response
    include Fleck::Loggable

    attr_accessor :id, :status, :errors, :headers, :body

    def initialize(request_id)
      @id = request_id
      logger.progname += " #{@id}"

      @status  = 200
      @errors  = []
      @headers = {}
      @body    = nil
    end

    def not_found(msg = nil)
      @status = 404
      @errors << 'Resource Not Found'
      @errors << msg if msg
    end

    def render_error(status, msg = [])
      @status = status.to_i
      if msg.is_a?(Array)
        @errors += msg
      else
        @errors << msg
      end
    end

    def to_json
      return Oj.dump({
        "status"  => @status,
        "errors"  => @errors,
        "headers" => @headers,
        "body"    => @body
      }, mode: :compat)
    rescue => e
      logger.error e.inspect + "\n" + e.backtrace.join("\n")
      return Oj.dump({
        "status" => 500,
        "errors" => ['Internal Server Error', 'Failed to dump the response to JSON']
      }, mode: :compat)
    end

    def to_s
      return self.inspect
    end
  end
end