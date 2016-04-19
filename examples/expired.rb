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
client = Fleck::Client.new(connection, "expiration.example.queue", concurrency: CONCURRENCY.to_i)
success_probability = 0.8

count   = 0
success = 0
failure = 0

mutex = Mutex.new
lock  = Mutex.new
condition = ConditionVariable.new

class MyConsumer < Fleck::Consumer
  configure queue: 'expiration.example.queue', concurrency: CONCURRENCY.to_i

  def on_message(request, response)
    case request.action
    when 'hello' then hello
    else
      response.not_found!
    end
  end

  def hello
    sleep rand
    response.body = "#{request.params[:num] + 1}. Hello!"
  end
end

SAMPLES.to_i.times do |num|
  client.request(action: 'hello', params: {num: num}, async: true, timeout: (success_probability * SAMPLES.to_f)/CONCURRENCY.to_f) do |request, response|
    if request.expired?
      puts "EXPIRED: #{response.inspect}"
    elsif response.status == 200
      puts "SUCCESS: #{response.body}"
    else
      puts "ERROR: #{response.inspect}"
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

at_exit do
  puts "Ztimer: (count: #{Ztimer.count}, jobs: #{Ztimer.jobs_count})"
  puts "Total: #{count}, Success: #{success}, Failure: #{failure}"
end

lock.synchronize { condition.wait(lock) }
exit