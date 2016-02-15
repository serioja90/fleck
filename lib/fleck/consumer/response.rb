
module Fleck
  class Consumer::Response
    include Fleck::Loggable

    attr_accessor :id, :status, :errors, :body

    def initialize(request_id)
      @id = request_id
      logger.progname += " #{@id}"

      @status = 200
      @errors = []
      @body   = nil
    end

    def not_found(msg = nil)
      @status = 404
      @errors << 'Resource Not Found'
      @errors << msg if msg
    end

    def render_error(status, messages = [])
      @status = status.to_i
      @errors += messages
    end

    def to_json
      return Oj.dump({
        "status" => @status,
        "errors" => @errors,
        "body"   => @body
      }, mode: :compat)
    rescue => e
      logger.error e.inspect + "\n" + e.backtrace.join("\n")
      return Oj.dump({
        "status" => 500,
        "errors" => ['Internal Server Error', 'Failed to dump the response to JSON']
      }, mode: :compat)
    end
  end
end