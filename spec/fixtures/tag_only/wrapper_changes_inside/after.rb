# frozen_string_literal: true

RSpec.describe Greeter::Core::Domain::GuestName do
  shared_examples 'an invalid guest name' do |raw|
    it "raises InvalidGuestName for #{raw.inspect}" do
      expect { described_class.new(raw) }
        .to raise_error(Greeter::Core::Domain::InvalidGuestName)
    end
  end

  context 'rejects an empty or whitespace-only name',
          requirement: 'demo-requirement',
          scenario: 'demo-scenario' do
    it_behaves_like 'an invalid guest name', ''
    it_behaves_like 'an invalid guest name', "\t"
  end
end
