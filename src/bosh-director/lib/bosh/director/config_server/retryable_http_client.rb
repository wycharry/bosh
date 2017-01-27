module Bosh::Director::ConfigServer
  class RetryableHTTPClient
    def initialize(http_client)
      @http_client = http_client
    end

    def get_by_id(id)
      connection_retryable.retryer do
        auth_retryable.retryer do
          response = @http_client.get_by_id(id)
          raise Bosh::Director::UAAAuthorizationError if response.kind_of? Net::HTTPUnauthorized
          response
        end
      end
    end

    def get(name)
      connection_retryable.retryer do
        auth_retryable.retryer do
          response = @http_client.get(name)
          raise Bosh::Director::UAAAuthorizationError if response.kind_of? Net::HTTPUnauthorized
          response
        end
      end
    end

    def post(body)
      connection_retryable.retryer do
        auth_retryable.retryer do
          response = @http_client.post(body)
          raise Bosh::Director::UAAAuthorizationError if response.kind_of? Net::HTTPUnauthorized
          response
        end
      end
    end

    private

    def connection_retryable
      handled_exceptions = [
          SocketError,
          Errno::ECONNREFUSED,
          Errno::ETIMEDOUT,
          Errno::ECONNRESET,
          ::Timeout::Error,
          ::HTTPClient::TimeoutError,
          ::HTTPClient::KeepAliveDisconnected,
          OpenSSL::SSL::SSLError,
      ]
      Bosh::Retryable.new({sleep: 0, tries: 3, on: handled_exceptions})
    end

    def auth_retryable
      handled_exceptions = [
          Bosh::Director::UAAAuthorizationError,
      ]
      Bosh::Retryable.new({sleep: 0, tries: 2, on: handled_exceptions})
    end
  end
end
