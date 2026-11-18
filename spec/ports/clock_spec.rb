# frozen_string_literal: true

RSpec.describe Greeter::Core::Ports::Clock do
  it 'raises NotImplementedError on #now',
     requirement: 'clock-port-declares-an-unimplemented-now',
     scenario: 'base-clock-now-raises-notimplementederror' do
    expect { described_class.new.now }.to raise_error(NotImplementedError)
  end
end
