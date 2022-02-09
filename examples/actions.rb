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

  action 'hello', "An action which returns 'Hello'"
  def hello
    ok! 'Hello!'
  end

  action 'ciao', "An action which returns 'Ciao'"
  param :world, type: 'boolean', required: true, default: false
  def my_custom_method
    ok! params[:world] ? 'Ciao, Mondo!' : 'Ciao!'
  end

  action :aloha
  param :number, type: 'integer', clamp: [1, 10], required: true
  param :name, type: 'string', default: 'John Doe', required: true
  def my_aloha
    ok! "#{params[:number]}. Aloha, #{params[:name]}!"
  end

  def not_an_action
    logger.warn("I'm not an action, so you should not be able to call me!")
  end
end

actions = %i[hello ciao aloha not_an_action]

SAMPLES.to_i.times do |num|
  action = actions.sample
  name = ['John Doe', 'Willie Wonka', 'Billie Smith'].sample
  client.request(action: action, params: { num: num, name: name, number: rand * 100, world: %w[yes no].sample }, timeout: 5) do |_, response|
    if response.status == 200
      Fleck.logger.info "ACTION: (#{action.inspect}) #{response.body}"
    else
      Fleck.logger.error "ACTION: (#{action.inspect}) #{response.errors.join(', ')} --- #{response.body}"
    end
  end
end
