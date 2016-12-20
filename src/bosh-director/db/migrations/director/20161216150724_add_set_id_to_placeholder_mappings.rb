require 'securerandom'

Sequel.migration do
  up do
    alter_table(:placeholder_mappings) do
      add_column(:set_id, String, null: false, default: 'initial')
      drop_index nil, :name => :placeholder_per_deployment
      add_index [:placeholder_name, :set_id], :unique => true, :name => :placeholder_set
    end

    alter_table(:deployments) do
      add_column(:placeholder_set_id, String, null: false, default: 'initial')
      add_column(:successful_placeholder_set_id, String)
    end

    alter_table(:instances) do
      add_column(:placeholder_set_id, String, null: false, default: 'initial')
    end

    self[:deployments].all do |deployment|
      set_id = SecureRandom.uuid
      deployment_id = deployment[:id]
      self[:placeholder_mappings].where(deployment_id: deployment_id).update(set_id: set_id)
      self[:instances].where(deployment_id: deployment_id).update(placeholder_set_id: set_id)
      self[:deployments].where(id: deployment_id).update(placeholder_set_id: set_id)
    end
  end

  down do
    alter_table :placeholder_mappings do
      drop_index nil, :name => :placeholder_set
      add_index [:placeholder_id, :deployment_id], :unique => true, :name => :placeholder_per_deployment
    end

    alter_table(:deployments) do
      drop_column(:placeholder_set_id)
      drop_column(:successful_placeholder_set_id)
    end

    alter_table(:instances) do
      drop_column(:placeholder_set_id)
    end
  end
end
