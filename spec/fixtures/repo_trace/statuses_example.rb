# frozen_string_literal: true

# Formatter fixture, run in a subprocess by
# spec/support/repo_trace_formatter_spec.rb. Not named *_spec.rb, so the main
# suite never loads it. The failure is deliberate.
RSpec.describe 'repo trace statuses fixture' do
  it 'passes', requirement: 'demo-requirement', scenario: 'demo-passes' do
    expect(1).to eq(1)
  end

  it 'fails', requirement: 'demo-requirement', scenario: 'demo-fails' do
    expect(1).to eq(2)
  end

  it 'is skipped', requirement: 'demo-requirement', scenario: 'demo-skipped', skip: 'fixture skip' do
    expect(1).to eq(1)
  end

  it 'is pending', requirement: 'demo-requirement', scenario: 'demo-pending' do
    pending 'fixture pending'
    expect(1).to eq(2)
  end

  it 'is untagged' do
    expect(1).to eq(1)
  end
end
