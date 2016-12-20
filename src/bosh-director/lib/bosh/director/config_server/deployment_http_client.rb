require 'net/http'
require 'json'

module Bosh::Director::ConfigServer
  class DeploymentHTTPClient

    def initialize(deployment_name, http_client)
      @http_client = http_client
      @placeholder_manager = Bosh::Director::PlaceholderManager.new(deployment_name)
    end

    def get_by_id(id)
      @http_client.get_by_id(id)
    end

    def get(name)
      response = @http_client.get(name)

      if response.kind_of? Net::HTTPOK
        response_body = JSON.parse(response.body)
        placeholder = response_body['data'][0]

        @placeholder_manager.add_mapping(placeholder['name'], placeholder['id'])
      end

      response
    end

    def post(body)
      @http_client.post(body)
    end
  end
end

