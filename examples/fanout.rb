#!/usr/bin/env ruby
# encoding: utf-8

require 'fleck'

user        = ENV['USER']        || 'guest'
pass        = ENV['PASS']        || 'guest'

CONCURRENCY = (ENV['CONCURRENCY'] || 10).to_i
SAMPLES     = (ENV['SAMPLES']     || 1_000).to_i

Fleck.configure do |config|
  config.default_user = user
  config.default_pass = pass
  config.loglevel     = Logger::DEBUG
end

connection = Fleck.connection(host: "127.0.0.1", port: 5672, user: user, pass: pass, vhost: "/")
client = Fleck::Client.new(connection, "example.queue", concurrency: CONCURRENCY.to_i, exchange_type: :fanout, exchange_name: 'fanout.example.queue', multiple_responses: true)

count   = 0
success = 0
failure = 0

mutex = Mutex.new
lock  = Mutex.new
condition = ConditionVariable.new

class First < Fleck::Consumer
  configure queue: "example.queue", concurrency: CONCURRENCY.to_i, exchange_type: :fanout, exchange_name: 'fanout.example.queue'

  action :incr
  def incr
    if request.action == 'incr'
      ok! "#{request.params[:num].to_i + 1}. Hello, World!"
    else
      not_found!
    end
  end
end

Thread.new do
  SAMPLES.times do |i|
    client.request(action: 'incr', params: { num: i }, timeout: 60) do |request, response|
      request.logger.debug response.body
      mutex.synchronize do
        count += 1
        if response.status == 200
          success += 1
        else
          failure += 1
        end

        lock.synchronize { condition.signal } if count >= SAMPLES
      end
    end
  end
end

lock.synchronize { condition.wait(lock) }

puts "Total: #{count}, Success: #{success}, Failure: #{failure}"
