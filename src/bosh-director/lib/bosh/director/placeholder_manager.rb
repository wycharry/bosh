module Bosh::Director
  class PlaceholderManager
    def self.get_mappings_for_set(set_id)
      results = Bosh::Director::Models::PlaceholderMapping.where(set_id: set_id).all
      mappings = {}
      for result in results do
        mappings[result.placeholder_name] = result.placeholder_id
      end
      mappings
    end

    def initialize(deployment_name)
      @deployment_model = Bosh::Director::Models::Deployment.find(name: deployment_name)
    end

    def add_mapping(placeholder_name, placeholder_id)
      attributes = {
        placeholder_name: placeholder_name,
        placeholder_id: placeholder_id,
        deployment_id: @deployment_model.id,
        set_id: @deployment_model.placeholder_set_id
      }
      Models::PlaceholderMapping.create(attributes)
    end

    # def prepare_placeholders_for_deploy
    #   Models::PlaceholderMapping.where(deployment_id: @deployment_model.id, state: "new").delete
    # end
  end
end