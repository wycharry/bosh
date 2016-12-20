require 'spec_helper'

module Bosh::Director
  describe PlaceholderManager do
    let(:deployment_name) { 'deployment_name' }
    subject(:manager) { Bosh::Director::PlaceholderManager.new(deployment_name) }

    it 'does things' do
      manager.nil?
    end

    context 'for a specific deployment' do
      context '#add_mapping' do
        before do
          Models::Deployment.create(name: deployment_name, placeholder_set_id: 'abc123', manifest: YAML.dump({'foo' => '((foo))', 'bar' => '((bar))'}))
        end

        it 'should insert the mapping into the database' do
          expect(Models::PlaceholderMapping.all.count).to eq(0)
          subject.add_mapping('random_name', '1')

          expect(Models::PlaceholderMapping.all.count).to eq(1)
          expect(Models::PlaceholderMapping.first.placeholder_name).to eq('random_name')
          expect(Models::PlaceholderMapping.first.placeholder_id).to eq('1')
          expect(Models::PlaceholderMapping.first.set_id).to eq('abc123')
        end

        it 'should throw an error if value already exists' do
          subject.add_mapping('random_name', '1')
          expect{
            subject.add_mapping('random_name', '1')
          }.to raise_error(Sequel::UniqueConstraintViolation)
        end
      end

      context '#get_mapping_for_set' do
        let(:set_id) { 'abc123' }
        it 'should return a map of placeholder_name=>placeholder_id' do
          deployment = Models::Deployment.create(name: deployment_name, placeholder_set_id: set_id, manifest: YAML.dump({'foo' => '((foo))', 'bar' => '((bar))'}))
          Models::PlaceholderMapping.create(placeholder_id: '0', placeholder_name: 'foo', set_id: set_id, deployment: deployment)
          Models::PlaceholderMapping.create(placeholder_id: '2', placeholder_name: 'bar', set_id: set_id, deployment: deployment)

          expected_result = [
            ['foo', '0'],
            ['bar', '2'],
          ]

          results = subject.get_mappings_for_set(set_id)
          expect(results.count).to equal(2)
          for idx in 0..1 do
            expected_name = expected_result[idx][0]
            expected_id = expected_result[idx][1]
            expect(results[expected_name]).to eq(expected_id)
          end
        end
      end

      # context '#prepare_placeholders_for_deploy' do
      #   before do
      #     # initial state
      #     Models::PlaceholderMapping.create(placeholder_id: '0', placeholder_name: 'foo', state: 'current', deployment: deployment_1)
      #     Models::PlaceholderMapping.create(placeholder_id: '2', placeholder_name: 'bar', state: 'current', deployment: deployment_1)
      #     Models::PlaceholderMapping.create(placeholder_id: '4', placeholder_name: 'mountain', state: 'current', deployment: deployment_2)
      #     Models::PlaceholderMapping.create(placeholder_id: '5', placeholder_name: 'chocolate', state: 'current', deployment: deployment_2)
      #
      #     # # on redeploy of deployment 1
      #     # Models::PlaceholderMapping.create(placeholder_id: '0', placeholder_name: 'foo', state: 'new', deployment: deployment)
      #     # Models::PlaceholderMapping.create(placeholder_id: '1', placeholder_name: 'bar', state: 'new', deployment: deployment)
      #   end
      #
      #   it 'should remove all placeholders where state is "new"' do
      #     Models::PlaceholderMapping.create(placeholder_id: '0', placeholder_name: 'foo', state: 'new', deployment: deployment_1)
      #     subject.prepare_placeholders_for_deploy
      #     mappings = Bosh::Director::Models::PlaceholderMapping.all
      #     expect(mappings.count).to eq(4)
      #   end
      #
      #   it 'should NOT remove placeholders for any other deployment' do
      #     Models::PlaceholderMapping.create(placeholder_id: '6', placeholder_name: 'mountain', state: 'new', deployment: deployment_2)
      #     subject.prepare_placeholders_for_deploy
      #     mappings = Bosh::Director::Models::PlaceholderMapping.where(deployment_id: deployment_2.id).all
      #     expect(mappings.count).to eq(3)
      #
      #     expected_results = [
      #       ['6', 'mountain', 'new', deployment_2.id],
      #       ['5', 'chocolate', 'current', deployment_2.id],
      #       ['4', 'mountain', 'current', deployment_2.id],
      #     ]
      #
      #     for result in expected_results do
      #       mapping = mappings.pop
      #
      #       expect(mapping.placeholder_id).to eq(result[0])
      #       expect(mapping.placeholder_name).to eq(result[1])
      #       expect(mapping.state).to eq(result[2])
      #       expect(mapping.deployment_id).to eq(result[3])
      #     end
      #
      #   end
      # end
    end
  end
end
