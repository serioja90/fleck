
module Fleck
  class Consumer::Request
    include Fleck::Loggable

    attr_reader :id, :metadata, :payload, :action, :data, :headers, :action, :version, :ip, :params, :status, :errors

    def initialize(metadata, payload, delivery_info)
      @id              = metadata.correlation_id
      logger.progname += " #{@id}"

      @metadata      = metadata
      @payload       = payload
      @exchange      = delivery_info.exchange.inspect
      @queue         = delivery_info.routing_key.inspect
      @data          = {}
      @headers       = (@metadata.headers || {}).to_hash_with_indifferent_access
      @action        = @metadata.type
      @version       = nil
      @ip            = nil
      @params        = {}
      @status        = 200
      @errors        = []

      parse_request!
    end

    protected

    def parse_request!
      @data = Oj.load(@payload, mode: :compat).to_hash_with_indifferent_access.filtered!
      @headers.merge!(@data["headers"] || {}).filtered!

      logger.debug "Processing request (exchange: #{@exchange}, queue: #{@queue}, options: #{@headers}, message: #{@data})"

      @action            ||= @headers["action"]
      @headers["action"] ||= @action
      @version             = @headers["version"]
      @ip                  = @headers["ip"]
      @params              = @data["params"] || {}
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