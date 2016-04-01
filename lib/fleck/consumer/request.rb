
module Fleck
  class Consumer::Request
    include Fleck::Loggable

    attr_reader :id, :metadata, :payload, :data, :headers, :action, :params, :status, :errors

    def initialize(metadata, payload)
      @id              = metadata.correlation_id
      logger.progname += " #{@id}"

      @metadata = metadata
      @payload  = payload
      @data     = {}
      @headers  = {}
      @action   = nil
      @params   = {}
      @status   = 200
      @errors   = []

      parse_request!
    end

    protected

    def parse_request!
      logger.debug "Parsing request: #{@payload}"
      @data    = Oj.load(@payload, mode: :compat).to_hash_with_indifferent_access
      @headers = @data["headers"] || {}
      @action  = @headers["action"]
      @params  = @data["params"] || {}
    rescue Oj::ParseError => e
      logger.error(e.inspect + "\n" + e.backtrace.join("\n"))
      @status = 400
      @errors << "Bad Request"
      @errors << e.inspect
    rescue => e
      logger.error(e.inspect + "\n" + e.backtrace.join("\n"))
      @status = 500
      @errors << "Internal Server Error"
    end
  end
end