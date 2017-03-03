require 'spec_helper'

describe Bosh::Director::NatsRpc do
  let(:logger) { double(:logger) }
  let(:nats) { instance_double('NATS') }
  let(:nats_url) { 'fake-nats-url' }
  let(:nats_server_ca_path) { '/path/to/happiness.pem' }
  let(:nats_options) { {uri: nats_url, ssl: true, :tls => { :ca_file => nats_server_ca_path }} }
  subject(:nats_rpc) { Bosh::Director::NatsRpc.new(nats_url, nats_server_ca_path) }

  before do
    allow(Bosh::Director::Config).to receive(:logger).and_return(logger)
    allow(logger).to receive(:debug)
    allow(Bosh::Director::Config).to receive(:process_uuid).and_return(123)
    allow(NATS).to receive(:connect).with(nats_options).and_return(nats)
    allow(nats).to receive(:connected?).and_return(true)
    allow(EM).to receive(:schedule).and_yield
    allow(nats_rpc).to receive(:generate_request_id).and_return('req1')
  end

  describe '#nats' do
    it 'returns a NATs client' do
      expect(NATS).to receive(:connect).with(nats_options).and_return(nats)
      expect(nats_rpc.nats).to eq(nats)
    end

    context 'when an error occurs due to incorrect configuration' do
      before do
        allow(NATS).to receive(:connect).with(nats_options).and_raise('a NATS error has occurred')
      end

      it 'throws the error' do
        expect{
          nats_rpc.nats
        }.to raise_error('An error has occurred while connecting to NATS: a NATS error has occurred')
      end
    end

    context 'when an error occurs due to a connection issue' do
      before do
        allow(logger).to receive(:error)
        expect(NATS).to receive(:connect).with(nats_options).and_return(nats)
        allow(NATS).to receive(:on_error) do | &blk |
          blk.call("Some Connection Issue")
        end
      end

      it 'throws the error' do
        expect{
          nats_rpc.nats
        }.to raise_error('An error has occurred while connecting to NATS: Some Connection Issue')
      end
    end

    context 'when connection cannot be established and the retries are exhausted' do
      before do
        allow(logger).to receive(:error)
        expect(NATS).to receive(:connect).with(nats_options).and_return(nats)
        allow(nats).to receive(:connected?).and_return(false)
      end

      it 'throws an error' do
        expect{
          nats_rpc.nats
        }.to raise_error('An error has occurred while connecting to NATS: Bosh::Common::RetryCountExceeded')
      end
    end
  end

  describe 'send_request' do
    it 'should publish a message to the client' do
      expect(nats).to receive(:subscribe).with('director.123.>')
      expect(nats).to receive(:publish) do |subject, message|
        expect(subject).to eql('test_client')
        payload = JSON.parse(message)
        expect(payload).to eql({
          'method' => 'a',
          'arguments' => [5],
          'reply_to' => 'director.123.req1'
        })
      end

      request_id = nats_rpc.send_request('test_client',  {'method' => 'a', 'arguments' => [5]})
      expect(request_id).to eql('req1')
    end

    it 'should execute the callback when the message is received' do
      subscribe_callback = nil
      expect(nats).to receive(:subscribe).with('director.123.>') do |&block|
        subscribe_callback = block
      end
      expect(nats).to receive(:publish) do
        subscribe_callback.call('', nil, 'director.123.req1')
      end

      callback_called = false
      nats_rpc.send_request('test_client', {'method' => 'a', 'arguments' => [5]}) do
        callback_called = true
      end
      expect(callback_called).to be(true)
    end

    it 'should execute the callback once even when two messages were received' do
      subscribe_callback = nil
      expect(nats).to receive(:subscribe).with('director.123.>') do |&block|
        subscribe_callback = block
      end
      expect(nats).to receive(:publish) do
        subscribe_callback.call('', nil, 'director.123.req1')
        subscribe_callback.call('', nil, 'director.123.req1')
      end

      called_times = 0
      nats_rpc.send_request('test_client', {'method' => 'a', 'arguments' => [5]}) do
        called_times += 1
      end
      expect(called_times).to eql(1)
    end

  end

  describe 'cancel_request' do
    it 'should not fire after cancel was called' do
      subscribe_callback = nil
      expect(nats).to receive(:subscribe).with('director.123.>') do |&block|
        subscribe_callback = block
      end
      expect(nats).to receive(:publish)

      called = false
      request_id = nats_rpc.send_request('test_client', {'method' => 'a', 'arguments' => [5]}) do
        called = true
      end
      expect(request_id).to eql('req1')

      nats_rpc.cancel_request('req1')
      subscribe_callback.call('', nil, 'director.123.req1')
      expect(called).to be(false)
    end
  end
end
