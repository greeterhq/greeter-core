# frozen_string_literal: true

RSpec.describe Greeter::Core::Domain::GreetingService do
  subject(:service) { described_class.new(clock: clock) }

  let(:fixed_time) { Time.utc(2024, 6, 1, 9, 0, 0) }
  let(:clock)      { Greeter::Core::Testing::FixedClock.new(fixed_time) }

  # Scenario: Greets a named guest
  describe '#greet' do
    it 'returns a Greeting for a valid name',
       requirement: 'greetingservice-composes-a-greeting-from-an-injected-clock',
       scenario: 'returns-a-greeting-for-a-valid-name' do
      result = service.greet('Alice')
      expect(result).to be_a(Greeter::Core::Domain::Greeting)
    end

    it 'sets greeted_at from the injected clock',
       requirement: 'greetingservice-composes-a-greeting-from-an-injected-clock',
       scenario: 'returns-a-greeting-for-a-valid-name' do
      result = service.greet('Alice')
      expect(result.greeted_at).to eq(fixed_time)
    end

    it 'sets guest_name with the display value from the raw input',
       requirement: 'greetingservice-composes-a-greeting-from-an-injected-clock',
       scenario: 'returns-a-greeting-for-a-valid-name' do
      result = service.greet('Alice')
      expect(result.guest_name.display).to eq('Alice')
    end

    # Scenario: Normalises casing and whitespace
    it 'normalises casing and whitespace in the returned guest_name' do
      result = service.greet('  alice smith  ')
      expect(result.guest_name.display).to eq('Alice Smith')
    end

    # Scenario: Rejects an empty or whitespace-only name
    it 'propagates InvalidGuestName for an empty name',
       requirement: 'greetingservice-composes-a-greeting-from-an-injected-clock',
       scenario: 'propagates-invalidguestname-for-bad-input' do
      expect { service.greet('') }
        .to raise_error(Greeter::Core::Domain::InvalidGuestName)
    end

    # Scenario: Rejects a name longer than 64 characters
    it 'propagates InvalidGuestName for a name longer than 64 characters',
       requirement: 'greetingservice-composes-a-greeting-from-an-injected-clock',
       scenario: 'propagates-invalidguestname-for-bad-input' do
      expect { service.greet('a' * 65) }
        .to raise_error(Greeter::Core::Domain::InvalidGuestName)
    end

    # Scenario: Rejects names containing control or escape characters
    it 'propagates InvalidGuestName for a name with an escape sequence',
       requirement: 'greetingservice-composes-a-greeting-from-an-injected-clock',
       scenario: 'propagates-invalidguestname-for-bad-input' do
      expect { service.greet("\e[31m") }
        .to raise_error(Greeter::Core::Domain::InvalidGuestName)
    end
  end
end
