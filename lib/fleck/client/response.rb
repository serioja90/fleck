
module Fleck
  class Client::Response
    include Fleck::Loggable

    attr_accessor :body, :status
    def initialize(payload)
      @data    = Oj.load(payload)
      @status  = @data["status"]
      @headers = @data["headers"] || {}
      @body    = @data["body"]
    end
  end
end