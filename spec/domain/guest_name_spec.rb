# frozen_string_literal: true

RSpec.describe Greeter::Core::Domain::GuestName do
  # ---------------------------------------------------------------------------
  # Shared examples — Scenario: Rejects an empty or whitespace-only name
  #                   Scenario: Rejects a name longer than 64 characters
  #                   Scenario: Rejects names containing control or escape characters
  # ---------------------------------------------------------------------------
  shared_examples 'an invalid guest name' do |raw|
    it "raises InvalidGuestName for #{raw.inspect}" do
      expect { described_class.new(raw) }
        .to raise_error(Greeter::Core::Domain::InvalidGuestName)
    end
  end

  it_behaves_like 'an invalid guest name', ''
  it_behaves_like 'an invalid guest name', '   '
  it_behaves_like 'an invalid guest name', 'a' * 65
  it_behaves_like 'an invalid guest name', "\e[31m"
  it_behaves_like 'an invalid guest name', "Alice\n"

  # ---------------------------------------------------------------------------
  # Scenario: Greets a named guest — value is preserved after construction
  # ---------------------------------------------------------------------------
  describe '#display' do
    it 'returns the raw value for a simple valid name' do
      expect(described_class.new('Alice').display).to eq('Alice')
    end

    # Scenario: Normalises casing and whitespace
    it 'strips surrounding whitespace and title-cases the name' do
      expect(described_class.new('  alice smith  ').display).to eq('Alice Smith')
    end

    it 'accepts a name of exactly 64 characters' do
      name = 'a' * 64
      expect { described_class.new(name) }.not_to raise_error
    end
  end

  # ---------------------------------------------------------------------------
  # Scenario: Equal names agree across ==, eql?, hash, and uniq
  # Value-object equality contract: == must be consistent with eql? and hash so
  # instances behave correctly as Hash keys and in Sets.
  # ---------------------------------------------------------------------------
  describe 'value equality' do
    let(:lower) { described_class.new('alice') }
    let(:upper) { described_class.new('Alice') }

    it 'agrees across ==, eql?, hash, Hash-key lookup, and uniq' do
      aggregate_failures 'equality contract' do
        expect(lower).to eq(upper)                # ==
        expect(lower).to eql(upper)               # eql?
        expect(lower.hash).to eq(upper.hash)      # hash
        expect({ lower => 1 }[upper]).to eq(1)    # Hash key
        expect([lower, upper].uniq.size).to eq(1) # Array#uniq
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Scenario: Rejects names containing control or escape characters
  # — additional control-character boundary cases
  # ---------------------------------------------------------------------------
  describe 'control-character rejection' do
    it 'rejects a name containing a null byte' do
      expect { described_class.new("Ali\x00ce") }
        .to raise_error(Greeter::Core::Domain::InvalidGuestName)
    end

    it 'rejects a name containing DEL (0x7F)' do
      expect { described_class.new("Ali\x7Fce") }
        .to raise_error(Greeter::Core::Domain::InvalidGuestName)
    end
  end
end
