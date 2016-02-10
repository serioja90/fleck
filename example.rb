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

conn = Bunny.new(host: "127.0.0.1", port: 5672, user: user, pass: pass, vhost: "/")
conn.start
ch = conn.create_channel
x  = ch.default_exchange
reply_queue = ch.queue("", exclusive: true)
reply_to = reply_queue.name
SAMPLES.times do |i|
  x.publish(i.to_s, routing_key: "example.queue", reply_to: reply_to, correlation_id: i)
end

puts "Starting queue consumption"

count = 0
mutex = Mutex.new

reply_queue.subscribe do |delivery_info, metadata, payload|
  puts payload
  mutex.synchronize { count += 1 }
end

class First < Fleck::Consumer
  configure queue: "example.queue", concurrency: CONCURRENCY.to_i

  def on_message(payload)
    return "#{payload.to_i + 1}. Hello, World!"
  end
end

while count < SAMPLES do
  sleep 0.01
end
puts "Total: #{count}"
First.consumers.map(&:terminate)