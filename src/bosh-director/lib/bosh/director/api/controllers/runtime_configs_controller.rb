require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class RuntimeConfigsController < BaseController
      post '/', :consumes => :yaml do
        manifest_text = request.body.read
        begin
          validate_manifest_yml(manifest_text, nil)
          Bosh::Director::Api::RuntimeConfigManager.new.update(manifest_text)
          create_event
        rescue => e
          create_event e
          raise e
        end

        status(201)
      end

      post '/diff', :consumes => :yaml do
        latest_runtime_config = Bosh::Director::Api::RuntimeConfigManager.new.latest
        old_runtime_config = if latest_runtime_config.nil?
          {}
        else
          latest_runtime_config.raw_manifest
        end

        new_runtime_config = validate_manifest_yml(request.body.read, nil)

        result = {}
        begin
          diff = Changeset.new(old_runtime_config, new_runtime_config).diff().order
          result['diff'] = diff.map { |l| [l.to_s, l.status] }
        rescue => error
          result['diff'] = []
          result['error'] = "Unable to diff manifest: #{error.inspect}\n#{error.backtrace.join("\n")}"
        end

        json_encode(result)
      end

      get '/', scope: :read do
        if params['limit'].nil? || params['limit'].empty?
          status(400)
          body("limit is required")
          return
        end

        begin
          limit = Integer(params['limit'])
        rescue ArgumentError
          status(400)
          body("limit is invalid: '#{params['limit']}' is not an integer")
          return
        end

        runtime_configs = Bosh::Director::Api::RuntimeConfigManager.new.list(limit)
        json_encode(
            runtime_configs.map do |runtime_config|
            {
              "properties" => runtime_config.properties,
              "created_at" => runtime_config.created_at,
            }
        end
        )
      end

      private
      def create_event(error = nil)
        @event_manager.create_event({
            user:        current_user,
            action:      "update",
            object_type: "runtime-config",
            error:       error
        })
      end
    end
  end
end
