require "logger"
require "rainbow"
require "rainbow/ext/string"
require "bunny"
require "fleck/version"
require "fleck/configuration"
require "fleck/consumer"

module Fleck
  @config = Configuration.new

  def self.configure
    yield @config if block_given?
    @config
  end

  def self.logger
    @config.logger
  end

  def self.register_consumer(consumer)
    unless @consumers.include?(consumer.class)
      @consumers << consumer.class
      consumer.class.new
    end
  end

  private

  class << self
    attr_reader :config
  end

end
