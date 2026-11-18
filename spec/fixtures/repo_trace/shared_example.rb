# frozen_string_literal: true

# Formatter fixture: one tagged shared example included twice, so both results
# share a location. One invocation passes and one fails.
RSpec.describe 'repo trace shared example fixture' do
  shared_examples 'a positive number' do |value|
    it 'is positive', requirement: 'demo-requirement', scenario: 'demo-shared' do
      expect(value).to be_positive
    end
  end

  it_behaves_like 'a positive number', 1
  it_behaves_like 'a positive number', -1
end
