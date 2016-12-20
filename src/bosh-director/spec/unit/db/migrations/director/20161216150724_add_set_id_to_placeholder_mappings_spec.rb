require 'db_spec_helper'
require 'securerandom'

module Bosh::Director
  describe 'add_set_id_to_placeholder_mappings' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20161216150724_add_set_id_to_placeholder_mappings.rb' }
    let(:set_id) { 'abc123' }

    before {
      allow(SecureRandom).to receive(:uuid).and_return(set_id)

      DBSpecHelper.migrate_all_before(migration_file)

      db[:deployments] << {id: 1, name: 'fake-deployment-name', manifest: '{}'}

      db[:vms] << {id: 1, agent_id: 'agent_id', deployment_id: 1}
      db[:instances] << {id: 1, deployment_id: 1, job: 'job_1', state: 'state', index: 0, vm_id: 1}

      db[:placeholder_mappings] << {id: 1, placeholder_id: '11', placeholder_name: 'placeholder_1', deployment_id: 1}
      db[:placeholder_mappings] << {id: 2, placeholder_id: '22', placeholder_name: 'placeholder_2', deployment_id: 1}

      DBSpecHelper.migrate(migration_file)
    }

    describe 'On update table' do
      it 'adds set_id column to placeholder_mappings table without losing data' do
        expect(db[:placeholder_mappings].count).to eq(2)
        expect(db[:placeholder_mappings].first[:placeholder_id]).to eq('11')
        expect(db[:placeholder_mappings].first[:placeholder_name]).to eq('placeholder_1')

        expect(db[:placeholder_mappings].first[:set_id]).to eq(set_id)
      end

      it 'adds placeholder_set_id column to deployments and instances table without losing data' do
        expect(db[:deployments].first[:placeholder_set_id]).to eq(set_id)
        expect(db[:instances].first[:placeholder_set_id]).to eq(set_id)

        expect(db[:deployments].count).to eq(1)
        expect(db[:instances].count).to eq(1)
      end
    end

    describe 'On updated unique constraint' do
      it 'throws error if it is not satisfied' do
        db[:placeholder_mappings] << {id: 5, placeholder_id: '15', placeholder_name: 'placeholder_5', deployment_id: 1, set_id: set_id}
        expect{
          db[:placeholder_mappings] << {id: 5, placeholder_id: '15', placeholder_name: 'placeholder_5', deployment_id: 1, set_id: set_id}
        }.to raise_error(Sequel::UniqueConstraintViolation)
      end

      it 'should have removed old constraint' do
        expect{
          db[:placeholder_mappings] << {id: 3, placeholder_id: '23', placeholder_name: 'placeholder_3', deployment_id: 1, set_id: 'initial'}
          db[:placeholder_mappings] << {id: 4, placeholder_id: '23', placeholder_name: 'placeholder_3', deployment_id: 1, set_id: set_id}
        }.to_not raise_error()
      end
    end
  end
end
