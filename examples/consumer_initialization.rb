#!/usr/bin/env ruby
# encoding: utf-8

require 'fleck'

user        = ENV['USER']        || 'guest'
pass        = ENV['PASS']        || 'guest'

CONCURRENCY = (ENV['CONCURRENCY'] || 2).to_i
SAMPLES     = (ENV['SAMPLES']     || 10).to_i

Fleck.configure do |config|
  config.default_user = user
  config.default_pass = pass
  config.loglevel     = Logger::DEBUG
end

connection = Fleck.connection(host: "127.0.0.1", port: 5672, user: user, pass: pass, vhost: "/")
client = Fleck::Client.new(connection, "consumer.initialization.example.queue", concurrency: CONCURRENCY.to_i)

class MyConsumer < Fleck::Consumer
  configure queue: 'consumer.initialization.example.queue', concurrency: CONCURRENCY.to_i
  actions :hello

  initialize do
    @value = "MY CONSUMER :) #{self.object_id}"
  end

  def hello
    response.body = "#{@value} Hello!"
  end
end

SAMPLES.to_i.times do |num|
  client.request(action: 'hello', params: {num: num}, timeout: 5) do |request, response|
    if response.status == 200
      Fleck.logger.info response.body
    else
      Fleck.logger.error response.errors.join(", ")
    end
  end
end