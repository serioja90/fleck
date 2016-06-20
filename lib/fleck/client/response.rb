
module Fleck
  class Client::Response
    include Fleck::Loggable

    attr_accessor :status, :headers, :body, :errors, :deprecated
    def initialize(payload)
      @data       = Oj.load(payload, mode: :compat).to_hash_with_indifferent_access.filtered!
      @status     = @data["status"]
      @headers    = @data["headers"] || {}
      @body       = @data["body"]
      @errors     = @data["errors"] || []
      @deprecated = !!@data["deprecated"]
    end

    def deprecated?
      @deprecated
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

    def inspect
      self.to_s
    end
  end
end