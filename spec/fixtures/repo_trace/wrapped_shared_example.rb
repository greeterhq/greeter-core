# frozen_string_literal: true

# Formatter fixture: an untagged shared example, included from inside tagged
# contexts. The results must carry the wrapping context's tags.
RSpec.describe 'repo trace wrapped shared example fixture' do
  shared_examples 'a positive number' do |value|
    it 'is positive' do
      expect(value).to be_positive
    end
  end

  context 'with the first scenario', requirement: 'demo-requirement', scenario: 'demo-wrapped-first' do
    it_behaves_like 'a positive number', 1
  end

  context 'with the second scenario', requirement: 'demo-requirement', scenario: 'demo-wrapped-second' do
    it_behaves_like 'a positive number', 2
  end
end
