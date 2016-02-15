
module Fleck
  class Client::Response
    include Fleck::Loggable

    attr_accessor :body, :status
    def initialize(payload)
      @data    = Oj.load(payload).to_hash_with_indifferent_access
      @status  = @data["status"]
      @headers = @data["headers"] || {}
      @body    = @data["body"]
    end
  end
end