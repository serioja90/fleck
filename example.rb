require 'fleck'

user        = ENV['USER']        || 'guest'
pass        = ENV['PASS']        || 'guest'

CONCURRENCY = (ENV['CONCURRENCY'] || 10).to_i
SAMPLES     = (ENV['SAMPLES']     || 10_000).to_i

Fleck.configure do |config|
  config.default_user = user
  config.default_pass = pass
  config.loglevel     = Logger::INFO
end

connection = Fleck.connection(host: "127.0.0.1", port: 5672, user: user, pass: pass, vhost: "/")
client = Fleck::Client.new(connection, "example.queue")

count = 0
mutex = Mutex.new
lock  = Mutex.new
condition = ConditionVariable.new

Thread.new do
  SAMPLES.times do |i|
    client.request({num: i}, true) do |request, response|
      puts response.body
      mutex.synchronize do
        count += 1
        lock.synchronize { condition.signal } if count >= SAMPLES
      end
    end
  end
end

class First < Fleck::Consumer
  configure queue: "example.queue", concurrency: CONCURRENCY.to_i

  def on_message(request, response)
    response.body = "#{request.params[:num].to_i + 1}. Hello, World!"
  end
end

lock.synchronize { condition.wait(lock) }

puts "Total: #{count}"
First.consumers.map(&:terminate)