# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Fleck::Core::Consumer do
  let(:consumer_class) do
    Class.new(Fleck::Consumer) do
      configure autostart: false
      actions :explode

      def explode
        response.render_error(400, ['Previous error'])
        response.headers['Sensitive'] = 'previous header'
        response.body = { sensitive: 'previous body' }
        deprecated!
        raise StandardError, 'sensitive exception detail'
      end
    end
  end
  let(:consumer) { consumer_class.new }
  let(:metadata) do
    Struct.new(:correlation_id, :headers, :type, :app_id, :reply_to)
          .new('request-id', {}, 'explode', 'client', 'reply.queue')
  end
  let(:delivery_info) do
    Struct.new(:exchange, :routing_key, :delivery_tag).new('', 'service.queue', 7)
  end
  let(:published_payloads) { [] }
  let(:publisher) do
    instance_double(Bunny::Exchange).tap do |publisher|
      allow(publisher).to receive(:publish) { |payload, **| published_payloads << payload }
    end
  end
  let(:channel) { instance_double(Bunny::Channel, closed?: false, ack: nil) }
  let(:logger) { instance_spy(Logger, debug: nil, error: nil, info: nil, warn: nil) }

  before do
    consumer.publisher = publisher
    consumer.channel = channel
    consumer.instance_variable_set(:@logger, logger)
  end

  after do
    consumer.channel = nil
  end

  it 'publishes and acknowledges a generic response for an unexpected action error' do
    consumer.send(:process_request!, metadata, '{"params":{}}', delivery_info)

    expect(consumer.response.status).to eq(500)
    expect(consumer.response.errors).to eq(['Internal Server Error'])
    expect(consumer.response.headers).to be_empty
    expect(consumer.response.body).to be_nil
    expect(consumer.response).not_to be_deprecated
    expect(Oj.load(published_payloads.fetch(0), mode: :compat)).to include(
      'status' => 500, 'errors' => ['Internal Server Error'], 'headers' => {}, 'body' => nil, 'deprecated' => false
    )
    expect(publisher).to have_received(:publish).with(
      consumer.response.to_json,
      routing_key: 'reply.queue', correlation_id: 'request-id', mandatory: false
    )
    expect(channel).to have_received(:ack).with(7)
    expect(logger).to have_received(:error).with(include('sensitive exception detail'))
  end

  it 'preserves details explicitly added by application code' do
    consumer.request = Fleck::Core::Consumer::Request.new(metadata, '{"params":{}}', delivery_info)
    consumer.send(:internal_server_error!, error: 'Application detail', interrupt: false)

    expect(consumer.response.status).to eq(500)
    expect(consumer.response.errors).to eq(['Internal Server Error', 'Application detail'])
  end
end
