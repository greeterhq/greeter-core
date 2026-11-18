# frozen_string_literal: true

RSpec.describe Greeter::Core::Domain::Greeting do
  subject(:greeting) { described_class.new(guest_name: guest_name, greeted_at: greeted_at) }

  let(:guest_name) { Greeter::Core::Domain::GuestName.new('Alice') }
  let(:greeted_at) { Time.utc(2024, 6, 1, 9, 0, 0) }

  # Scenario: Greets a named guest — value object holds the right data
  it 'exposes guest_name',
     requirement: 'greeting-is-an-immutable-value-object',
     scenario: 'greeting-holds-its-fields-and-is-frozen' do
    expect(greeting.guest_name).to eq(guest_name)
  end

  it 'exposes greeted_at',
     requirement: 'greeting-is-an-immutable-value-object',
     scenario: 'greeting-holds-its-fields-and-is-frozen' do
    expect(greeting.greeted_at).to eq(greeted_at)
  end

  it 'is frozen',
     requirement: 'greeting-is-an-immutable-value-object',
     scenario: 'greeting-holds-its-fields-and-is-frozen' do
    expect(greeting).to be_frozen
  end
end
