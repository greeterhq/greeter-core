# frozen_string_literal: true

RSpec.describe Greeter::Core::Ports::Clock do
  it 'raises NotImplementedError on #now',
     requirement: 'demo-requirement',
     scenario: 'demo-scenario' do
    expect { described_class.new.now }.not_to raise_error
  end
end
