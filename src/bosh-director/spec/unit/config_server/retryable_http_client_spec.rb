require 'spec_helper'
require 'httpclient'

describe Bosh::Director::ConfigServer::RetryableHTTPClient do
  subject { Bosh::Director::ConfigServer::RetryableHTTPClient.new(http_client) }
  let(:http_client) { instance_double('Bosh::Director::ConfigServer::HTTPClient') }
  let(:connection_error) { Errno::ECONNREFUSED.new('') }
  let(:successful_response) { Net::HTTPSuccess.new(nil, "200", nil) }
  let(:unauthorized_response) { Net::HTTPUnauthorized.new(nil, "401", nil) }

  let(:handled_connection_exceptions) {
    [
        SocketError,
        Errno::ECONNREFUSED,
        Errno::ETIMEDOUT,
        Errno::ECONNRESET,
        Timeout::Error,
        HTTPClient::TimeoutError,
        HTTPClient::KeepAliveDisconnected,
        OpenSSL::SSL::SSLError
    ]
  }

  describe '#get_by_id' do
    it 'should call `get_by_id` on the passed in http_client with same arguments' do
      expect(http_client).to receive(:get_by_id).with('id').and_return(successful_response)
      subject.get_by_id('id')
    end

    context 'when `get_by_id` call fails due to a connection error' do
      it 'throws a connection error after trying 3 times' do
        expect(http_client).to receive(:get_by_id).with('boo').and_raise(connection_error).exactly(3).times
        expect { subject.get_by_id('boo') }.to raise_error(connection_error)
      end
    end

    context 'when `get_by_id` call fails due to a connection error and then recovers on a subsequent retry' do
      before do
        count = 0
        allow(http_client).to receive(:get_by_id) do
          count += 1
          if count < 3
            raise connection_error
          end
          successful_response
        end
      end

      it 'does NOT raise an exception' do
        expect(http_client).to receive(:get_by_id).exactly(3).times
        expect { subject.get_by_id('/hi/ya') }.to_not raise_error
      end
    end

    it 'sets the appropriate exceptions to handle on retryable' do
      retryable = double("Bosh::Retryable")
      allow(retryable).to receive(:retryer).and_return(successful_response)

      allow(Bosh::Retryable).to receive(:new).with({sleep: 0, tries: 3, on: handled_connection_exceptions}).and_return(retryable)

      subject.get_by_id('boo')
    end

    context 'when `get_by_id` call fails with 401 unauthorized' do
      it 'throws an unauthorized error after retrying' do
        expect(http_client).to receive(:get_by_id).with('boo').and_return(unauthorized_response).exactly(2).times
        expect { subject.get_by_id('boo') }.to raise_error(Bosh::Director::UAAAuthorizationError)
      end
    end
  end

  describe '#get' do
    it 'should call `get` on the passed in http_client with same arguments' do
      expect(http_client).to receive(:get).with('id').and_return(successful_response)
      subject.get('id')
    end

    context 'when `get` call fails due to a connection error' do
      it 'throws a connection error after trying 3 times' do
        expect(http_client).to receive(:get).with('boo').and_raise(connection_error).exactly(3).times
        expect { subject.get('boo') }.to raise_error(connection_error)
      end
    end

    context 'when `get` call fails due to a connection error and then recovers on a subsequent retry' do
      before do
        count = 0
        allow(http_client).to receive(:get) do
          count += 1
          if count < 3
            raise connection_error
          end
          successful_response
        end
      end

      it 'does NOT raise an exception' do
        expect(http_client).to receive(:get).exactly(3).times
        expect { subject.get('/hi/ya') }.to_not raise_error
      end
    end

    it 'sets the appropriate exceptions to handle on retryable' do
      retryable = double("Bosh::Retryable")
      allow(retryable).to receive(:retryer).and_return(successful_response)

      allow(Bosh::Retryable).to receive(:new).with({sleep: 0, tries: 3, on: handled_connection_exceptions}).and_return(retryable)

      subject.get('boo')
    end

    context 'when `get` call fails with 401 unauthorized' do
      it 'throws an unauthorized error after retrying' do
        expect(http_client).to receive(:get).with('boo').and_return(unauthorized_response).exactly(2).times
        expect { subject.get('boo') }.to raise_error(Bosh::Director::UAAAuthorizationError)
      end
    end
  end

  describe '#post' do
    it 'should call `post` on the passed in http_client with same arguments' do
      expect(http_client).to receive(:post).with('{body}').and_return(successful_response)
      subject.post('{body}')
    end

    context 'when `post` call fails due to a connection error' do
      it 'throws a connection error after trying 3 times' do
        expect(http_client).to receive(:post).with('{body}').and_raise(connection_error).exactly(3).times
        expect { subject.post('{body}') }.to raise_error(connection_error)
      end
    end

    context 'when `post` call fails due to a connection error and then recovers on a subsequent retry' do
      before do
        count = 0
        allow(http_client).to receive(:post) do
          count += 1
          if count < 3
            raise connection_error
          end
          successful_response
        end
      end

      it 'does NOT raise an exception' do
        expect(http_client).to receive(:post).exactly(3).times
        expect { subject.post('{body}') }.to_not raise_error
      end
    end

    it 'sets the appropriate exceptions to handle on retryable' do
      retryable = double("Bosh::Retryable")
      allow(retryable).to receive(:retryer).and_return(successful_response)

      allow(Bosh::Retryable).to receive(:new).with({sleep: 0, tries: 3, on: handled_connection_exceptions}).and_return(retryable)

      subject.post('{body}')
    end

    context 'when `post` call fails with 401 unauthorized' do
      it 'throws an unauthorized error after retrying' do
        expect(http_client).to receive(:post).with('boo').and_return(unauthorized_response).exactly(2).times
        expect { subject.post('boo') }.to raise_error(Bosh::Director::UAAAuthorizationError)
      end
    end
  end
end