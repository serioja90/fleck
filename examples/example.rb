#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fleck'

user        = ENV['USER']        || 'guest'
pass        = ENV['PASS']        || 'guest'

CONCURRENCY = (ENV['CONCURRENCY'] || 10).to_i
SAMPLES     = (ENV['SAMPLES']     || 10_000).to_i
QUEUE       = 'example.queue'

Fleck.configure do |config|
  config.default_user = user
  config.default_pass = pass
  config.loglevel     = Logger::DEBUG
end

client = Fleck::Client.new(Fleck.connection, QUEUE, concurrency: CONCURRENCY.to_i)

count   = 0
success = 0
failure = 0

mutex = Mutex.new
lock  = Mutex.new
condition = ConditionVariable.new

class First < Fleck::Consumer
  configure queue: QUEUE, concurrency: CONCURRENCY.to_i

  def on_message
    if rand > 0.1
      not_found! if request.action != 'incr'

      ok! "#{params[:num].to_i + 1}. Hello, World!"
    else
      logger.warn "REJECTING REQUEST {headers: #{headers}, params: #{params}"
      response.reject!(requeue: true)
    end
  end
end

Thread.new do
  SAMPLES.times do |i|
    client.request(
      action: 'incr',
      params: { num: i, secret: 'supersecret' },
      async: true,
      timeout: 1,
      rmq_options: { priority: (rand * 9).round(0), mandatory: false }
    ) do |request, response|
      if response.status == 200
        request.logger.debug response.body
      else
        request.logger.error "#{response.status} #{response.errors.join(', ')}"
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

lock.synchronize { condition.wait(lock) }

puts "Total: #{count}, Success: #{success}, Failure: #{failure}"
