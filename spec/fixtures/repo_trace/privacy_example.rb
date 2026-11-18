# frozen_string_literal: true

# Formatter fixture: a guest name appears in the description and in the
# failure message. Neither may reach the trace file.
RSpec.describe 'repo trace privacy fixture for Alice Smith' do
  it 'greets Alice Smith', requirement: 'demo-requirement', scenario: 'demo-privacy' do
    expect('Alice Smith').to eq('Bob Jones')
  end
end
