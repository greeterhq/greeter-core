# frozen_string_literal: true

# Formatter fixture: a requirement tag that is not a slug (a guest name).
RSpec.describe 'repo trace malformed tag fixture' do
  it 'is tagged with a non-slug', requirement: 'Alice Smith', scenario: 'demo-malformed' do
    expect(1).to eq(1)
  end
end
