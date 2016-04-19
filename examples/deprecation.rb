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
client = Fleck::Client.new(connection, "deprecation.example.queue")

class MyConsumer < Fleck::Consumer
  configure queue: 'deprecation.example.queue', concurrency: CONCURRENCY.to_i

  def on_message(request, response)
    case request.action
    when 'hello' then hello
    else
      response.not_found!
    end
  end

  def hello
    version = request.version || 'v1'
    case version.to_s
    when 'v1' then hello_v1
    when 'v2' then hello_v2
    else
      response.not_found!
    end
  end

  private

  def hello_v1
    deprecated!
    response.body = "#{request.params[:num]}. Hello V1!"
  end

  def hello_v2
    response.body = "#{request.params[:num] + 1}. Hello V2!"
  end
end

SAMPLES.to_i.times do |num|
  response = client.request(action: 'hello', version: (rand >= 0.5 ? 'v2' : 'v1'), params: {num: num}, timeout: 5)
  puts (response.deprecated? ? "DEPRECATED: #{response.body}" : response.body)
end