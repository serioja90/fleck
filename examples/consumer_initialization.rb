#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fleck'

user        = ENV['USER']        || 'guest'
pass        = ENV['PASS']        || 'guest'

CONCURRENCY = (ENV['CONCURRENCY'] || 2).to_i
SAMPLES     = (ENV['SAMPLES']     || 10).to_i
QUEUE = 'consumer.initialization.example.queue'

Fleck.configure do |config|
  config.default_user = user
  config.default_pass = pass
  config.loglevel     = Logger::DEBUG
end

connection = Fleck.connection(host: '127.0.0.1', port: 5672, user: user, pass: pass, vhost: '/')
client = Fleck::Client.new(connection, QUEUE, concurrency: CONCURRENCY.to_i)

class MyConsumer < Fleck::Consumer
  configure queue: QUEUE, concurrency: CONCURRENCY.to_i
  actions :hello

  initialize do
    @value = "MY CONSUMER :) #{object_id}"
  end

  def hello
    logger.info '---------------- HELLO ----------------'
    ok! "#{@value} Hello!"
  end
end

SAMPLES.to_i.times do |num|
  client.request(action: 'hello', params: {num: num}, timeout: 5) do |_, response|
    if response.status == 200
      Fleck.logger.info response.body
    else
      Fleck.logger.error response.errors.join(', ')
    end
  end
end
