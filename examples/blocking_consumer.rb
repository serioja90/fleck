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
client = Fleck::Client.new(connection, "blocking.consumer.example.queue")

class MyConsumer < Fleck::Consumer
  configure queue: 'blocking.consumer.example.queue', autostart: false
  actions :quit

  initialize do
    @value = "MY CONSUMER :) #{object_id}"
  end

  def quit
    logger.debug "Quit message received, but I'm goint to sleep for 2 seconds ..."
    sleep 2
    logger.debug "Let's terminate this example!"
    Ztimer.async { terminate }
  end
end

client.request(action: 'quit', timeout: 5, async: true)

MyConsumer.start(block: true)

puts "We did it :)"
sleep 0.01 # Give some time to Bunny to cancel subscribtions and to close channels and connections
