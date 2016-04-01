
module Fleck
  class Client::Response
    include Fleck::Loggable

    attr_accessor :status, :headers, :body, :errors
    def initialize(payload)
      @data    = Oj.load(payload, mode: :compat).to_hash_with_indifferent_access
      @status  = @data["status"]
      @headers = @data["headers"] || {}
      @body    = @data["body"]
      @errors  = @data["errors"] || []
    end
  end
end