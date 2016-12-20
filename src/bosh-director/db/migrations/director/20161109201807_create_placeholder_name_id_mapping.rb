Sequel.migration do
  up do
    create_table :placeholder_mappings do
      primary_key :id
      String :placeholder_id, :null => false
      String :placeholder_name, :null => false
      foreign_key :deployment_id, :deployments, :null => false, :on_delete => :cascade
    end

    alter_table :placeholder_mappings do
      add_index [:placeholder_id, :deployment_id], :unique => true, :name => :placeholder_per_deployment
    end
  end

  down do
    drop_table :placeholder_mappings
  end
end