# frozen_string_literal: true

RSpec.describe Greeter::Core::Ports::GreetingPresenter do
  it 'raises NotImplementedError on #present',
     requirement: 'greetingpresenter-port-declares-an-unimplemented-present',
     scenario: 'base-greetingpresenter-present-raises-notimplementederror' do
    expect { described_class.new.present(double) }.to raise_error(NotImplementedError)
  end
end
