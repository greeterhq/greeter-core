# frozen_string_literal: true

RSpec.describe Greeter::Core::Domain::GuestName do
  shared_examples 'an invalid guest name' do |raw|
    it "raises InvalidGuestName for #{raw.inspect}" do
      expect { described_class.new(raw) }
        .to raise_error(Greeter::Core::Domain::InvalidGuestName)
    end
  end

  it_behaves_like 'an invalid guest name', ''
  it_behaves_like 'an invalid guest name', '   '
end
