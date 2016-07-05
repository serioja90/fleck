#!/usr/bin/env ruby
# encoding: utf-8

require 'fleck'

user        = ENV['USER']        || 'guest'
pass        = ENV['PASS']        || 'guest'

CONCURRENCY = (ENV['CONCURRENCY'] || 10).to_i
SAMPLES     = (ENV['SAMPLES']     || 10_000).to_i

Fleck.configure do |config|
  config.default_user = user
  config.default_pass = pass
  config.loglevel     = Logger::DEBUG
end

client = Fleck::Client.new(Fleck.connection, "example.queue", concurrency: CONCURRENCY.to_i)

count   = 0
success = 0
failure = 0

mutex = Mutex.new
lock  = Mutex.new
condition = ConditionVariable.new

class First < Fleck::Consumer
  configure queue: "example.queue", concurrency: CONCURRENCY.to_i

  def on_message(request, response)
    if rand > 0.1
      if request.action == "incr"
        response.body = "#{request.params[:num].to_i + 1}. Hello, World!"
      else
        response.not_found
      end
    else
      logger.warn "REJECTING REQUEST {headers: #{request.headers}, params: #{request.params}"
      response.reject!(requeue: true)
    end
  end
end

Thread.new do
  SAMPLES.times do |i|
    client.request(action: 'incr', params: {num: i, secret: 'supersecret'}, async: true, timeout: 1, rmq_options: { priority: (rand * 9).round(0), mandatory: false}) do |request, response|
      if response.status == 200
        request.logger.debug response.body
      else
        request.logger.error "#{response.status} #{response.errors.join(", ")}"
      end
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

at_exit do
  puts "Total: #{count}, Success: #{success}, Failure: #{failure}"
end

lock.synchronize { condition.wait(lock) }
exit

#First.consumers.map(&:terminate)