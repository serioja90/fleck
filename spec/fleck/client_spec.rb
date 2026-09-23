# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Fleck::Client do
  it 'routes requests to the recovered reply queue after Bunny changes its server-assigned name' do
    bindings = []
    queue = Bunny::Queue.allocate
    queue.instance_variable_set(:@name, 'reply.before')
    queue.instance_variable_set(:@server_named, true)
    queue.instance_variable_set(:@options, {})
    queue.instance_variable_set(:@bindings, [])

    channel = instance_double(Bunny::Channel, closed?: false, close: nil, register_queue: nil,
                                              deregister_queue_named: nil)
    allow(channel).to receive(:queue).with('', exclusive: true, auto_delete: true).and_return(queue)
    allow(channel).to receive(:queue_bind) do |name, _exchange, opts|
      bindings << [name, opts.fetch(:routing_key)]
    end
    allow(channel).to receive(:queue_declare).and_return(Struct.new(:queue).new('reply.after'),
                                                         Struct.new(:queue).new('reply.again'))
    queue.instance_variable_set(:@channel, channel)
    allow(queue).to receive(:subscribe).and_return(Object.new)

    address = instance_double(Addrinfo, ip_address: '127.0.0.1')
    socket = double(local_address: address, remote_address: address)
    connection = instance_double(Bunny::Session, transport: double(socket: socket), create_channel: channel)
    exchange = instance_double(Bunny::Exchange, name: 'fleck', on_return: nil)
    publisher = instance_double(Bunny::Exchange)
    published = []
    allow(publisher).to receive(:publish) { |_data, options| published << options }
    allow(Bunny::Exchange).to receive(:new).and_return(exchange, publisher)

    client = described_class.new(connection, 'service.queue')
    client.request(action: 'get', async: true)
    expect(published.last.fetch(:reply_to)).to eq('reply.before')

    queue.recover_from_network_failure
    expect(queue.name).to eq('reply.after')

    client.request(action: 'get', async: true)
    expect(bindings).to include(['reply.after', published.last.fetch(:reply_to)])

    queue.recover_from_network_failure
    client.request(action: 'get', async: true)
    expect(bindings).to include(['reply.again', published.last.fetch(:reply_to)])
  ensure
    client.terminate if client && !client.terminated
  end
end
