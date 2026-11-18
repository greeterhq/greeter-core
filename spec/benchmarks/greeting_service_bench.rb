# frozen_string_literal: true

require 'greeter/core'
require 'greeter/core/testing'

# Scenario: Completes #greet in under 5 ms at p99
#
# Domain-core latency guarantee (greeting-core capability). Exercised without
# any adapter: GreetingService is driven with a FixedClock in a warmed loop.
# Uses Process.clock_gettime for sub-millisecond wall-clock measurement.
RSpec.describe 'GreetingService latency' do
  let(:clock)   { Greeter::Core::Testing::FixedClock.new(Time.utc(2024, 6, 1, 9, 0, 0)) }
  let(:service) { Greeter::Core::Domain::GreetingService.new(clock: clock) }

  it 'completes #greet in under 5 ms at p99 over 200 iterations',
     requirement: 'greeting-construction-stays-within-latency-budget',
     scenario: 'completes-greet-in-under-5-ms-at-p99' do
    # Warm up
    50.times { service.greet('Alice') }

    iterations = 200
    samples = Array.new(iterations) do
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      service.greet('Alice')
      (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000.0
    end

    samples.sort!
    p99 = samples[(iterations * 0.99).ceil - 1]

    expect(p99).to be < 5.0,
                   "p99 latency #{p99.round(3)} ms exceeded 5 ms budget"
  end
end
