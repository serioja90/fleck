# frozen_string_literal: true

require 'spec_helper'
require 'open3'

RSpec.describe Fleck::Core::Consumer::Request do
  subject(:request) { described_class.new(metadata, payload, delivery_info) }

  let(:metadata) do
    Struct.new(:correlation_id, :headers, :type, :app_id, :reply_to)
          .new('request-id', {}, 'search', 'client', 'reply.queue')
  end
  let(:delivery_info) do
    Struct.new(:exchange, :routing_key, :delivery_tag).new('', 'service.queue', 1)
  end

  context 'with valid JSON' do
    let(:payload) { '{"headers":{"version":"v2"},"params":{"page":2}}' }

    it 'parses headers and params without failing the request' do
      expect(request).not_to be_failed
      expect(request.version).to eq('v2')
      expect(request.params).to eq('page' => 2)
      expect(request.response.status).to eq(200)
    end
  end

  context 'with malformed JSON' do
    let(:payload) { '{' }

    it 'returns a failed bad-request response' do
      expect(request).to be_failed
      expect(request.response.status).to eq(400)
      expect(request.response.errors.first).to eq('Bad Request')
      expect(request.response.errors.last).to be_a(String)
      expect(request.response.body).to be_nil
    end
  end

  context 'when Oj mimics JSON parser errors' do
    it 'returns a failed bad-request response' do
      script = <<~RUBY
        require 'oj'
        Oj.mimic_JSON
        require 'fleck'
        Fleck.configure { |config| config.logger = nil }

        metadata = Struct.new(:correlation_id, :headers, :type, :app_id, :reply_to)
                         .new('request-id', {}, 'search', 'client', 'reply.queue')
        delivery = Struct.new(:exchange, :routing_key, :delivery_tag)
                         .new('', 'service.queue', 1)
        request = Fleck::Core::Consumer::Request.new(metadata, '{', delivery)
        puts request.response.to_json
      RUBY

      stdout, _stderr, status = Open3.capture3(
        RbConfig.ruby, "-I#{File.expand_path('../../../../lib', __dir__)}", '-e', script
      )
      response = Oj.load(stdout, mode: :compat)

      expect(status).to be_success
      expect(response).to include('status' => 400, 'body' => nil)
      expect(response.fetch('errors').first).to eq('Bad Request')
      expect(response.fetch('errors').last).to include('JSON::ParserError')
    end
  end

  context 'with an unexpected parsing failure' do
    let(:payload) { '{}' }

    before do
      allow(Oj).to receive(:load).and_raise(StandardError, 'unexpected failure')
    end

    it 'returns a failed internal-server-error response' do
      expect(request).to be_failed
      expect(request.response.status).to eq(500)
      expect(request.response.errors.first).to eq('Internal Server Error')
    end
  end
end
