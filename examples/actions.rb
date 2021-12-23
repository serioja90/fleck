#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fleck'

user        = ENV['USER']        || 'guest'
pass        = ENV['PASS']        || 'guest'

CONCURRENCY = (ENV['CONCURRENCY'] || 2).to_i
SAMPLES     = (ENV['SAMPLES']     || 10).to_i
QUEUE       = 'actions.example.queue'

Fleck.configure do |config|
  config.default_user = user
  config.default_pass = pass
  config.loglevel     = Logger::DEBUG
end

connection = Fleck.connection(host: '127.0.0.1', port: 5672, user: user, pass: pass, vhost: '/')
client = Fleck::Client.new(connection, QUEUE, concurrency: CONCURRENCY.to_i)

class MyConsumer < Fleck::Consumer
  configure queue: QUEUE, concurrency: CONCURRENCY.to_i
  actions :hello, ciao: 'my_custom_method', aloha: 'my_aloha'

  def hello
    ok! 'Hello!'
  end

  def my_custom_method
    ok! 'Ciao!'
  end

  def my_aloha
    ok! 'Aloha!'
  end

  def not_an_action
    logger.warn("I'm not an action, so you should not be able to call me!")
  end
end

actions = %i[hello ciao aloha not_an_action]

SAMPLES.to_i.times do |num|
  action = actions[(rand * actions.size).to_i]
  client.request(action: action, params: { num: num }, timeout: 5) do |_, response|
    if response.status == 200
      Fleck.logger.info "ACTION: (#{action.inspect}) #{response.body}"
    else
      Fleck.logger.error "ACTION: (#{action.inspect}) #{response.errors.join(', ')}"
    end
  end
end
