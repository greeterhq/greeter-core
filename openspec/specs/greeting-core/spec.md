# greeting-core Specification

## Purpose

Provides the pure domain of the Greeter system: a validated `GuestName` value
object, an immutable `Greeting` value object, and a `GreetingService` use case
that composes them from an injected clock. This capability is exercisable
without any adapter, proving the inner edge of the hexagonal seam. All
behaviour here is deterministic and free of I/O.

Traceability note: each scenario below maps to exactly one RSpec example in the
gem's `spec/` suite (this gem has no Cucumber).

## Requirements

### Requirement: Validates and normalises a guest name
`GuestName.new(raw)` SHALL strip surrounding whitespace and present the result
in title case via `#display`. Construction SHALL be eager and the resulting
object SHALL be frozen.

#### Scenario: Normalises whitespace and casing
- **WHEN** `GuestName.new("  alice smith  ")` is constructed
- **THEN** `#display` returns `"Alice Smith"`
- Maps to: `spec/domain/guest_name_spec.rb`

### Requirement: Rejects an empty or whitespace-only name
`GuestName.new(raw)` SHALL raise `Greeter::Core::Domain::InvalidGuestName`
(a subclass of `ArgumentError`) when the name is empty or contains only
whitespace after stripping.

#### Scenario: Rejects an empty or whitespace-only name
- **WHEN** `GuestName.new("")` or a whitespace-only string is constructed
- **THEN** it raises `Greeter::Core::Domain::InvalidGuestName`
- Maps to: `spec/domain/guest_name_spec.rb`

### Requirement: Rejects a name longer than 64 characters
`GuestName.new(raw)` SHALL raise `Greeter::Core::Domain::InvalidGuestName` when
the name exceeds 64 characters after whitespace-stripping.

#### Scenario: Rejects a name longer than 64 characters
- **WHEN** `GuestName.new("A" * 65)` is constructed
- **THEN** it raises `Greeter::Core::Domain::InvalidGuestName`
- Maps to: `spec/domain/guest_name_spec.rb`

### Requirement: Rejects names containing control or escape characters
`GuestName.new(raw)` SHALL raise `Greeter::Core::Domain::InvalidGuestName` when
the raw input contains ASCII control characters (codepoints 0x00–0x1F, 0x7F) or
escape sequences, as a defence against log-injection attacks.

#### Scenario: Rejects a name containing a control or escape character
- **WHEN** `GuestName.new` is called with a string containing a control byte or escape sequence (e.g. `"\x1b[31m"` or a NUL byte)
- **THEN** it raises `Greeter::Core::Domain::InvalidGuestName`
- Maps to: `spec/domain/guest_name_spec.rb`

### Requirement: Greeting is an immutable value object
`Greeting` SHALL hold `guest_name` and `greeted_at`, expose them as readers,
carry no presentation logic (no `#to_s`/`#message`), and be frozen on
construction.

#### Scenario: Greeting holds its fields and is frozen
- **WHEN** a `Greeting` is constructed with a `guest_name` and a `greeted_at`
- **THEN** it exposes both via readers and responds to `frozen?` with `true`
- Maps to: `spec/domain/greeting_spec.rb`

### Requirement: GreetingService composes a Greeting from an injected clock
`GreetingService#greet(raw_name)` SHALL construct a `GuestName` from the raw
input and return a `Greeting` whose `greeted_at` is read from the injected
clock's `#now`. It SHALL NOT rescue validation errors; `InvalidGuestName`
propagates to the caller.

#### Scenario: Returns a Greeting for a valid name
- **WHEN** `GreetingService#greet("Alice")` is called with an injected clock returning a fixed time
- **THEN** it returns a `Greeting` whose `guest_name.display` is `"Alice"` and whose `greeted_at` equals the clock's fixed time
- Maps to: `spec/domain/greet_guest_spec.rb`

#### Scenario: Propagates InvalidGuestName for bad input
- **WHEN** `GreetingService#greet` is called with an empty, over-long, or control-character name
- **THEN** it raises `Greeter::Core::Domain::InvalidGuestName` without rescuing
- Maps to: `spec/domain/greet_guest_spec.rb`

### Requirement: Greeting construction stays within latency budget
`GreetingService#greet` SHALL complete in under 5 ms at p99 when driven with a
fixed clock in a tight loop, measured in-process. This is a domain-core
guarantee independent of any adapter or process start-up cost.

#### Scenario: Completes #greet in under 5 ms at p99
- **WHEN** `GreetingService#greet` is called with a valid name and a `Greeter::Core::Testing::FixedClock` across a warmed benchmark loop
- **THEN** the p99 wall-clock time per iteration is below 5 ms
- Maps to: `spec/benchmarks/greeting_service_bench.rb`

### Requirement: GuestName is a value object with a consistent equality contract
`GuestName` SHALL implement `==`, `eql?`, and `hash` consistently so that two
instances whose normalised `#display` values are equal compare equal under all
three. Equal names MUST therefore behave as the same key in a Hash, as the same
member in a Set, and collapse to a single element under `Array#uniq`.

#### Scenario: Equal names agree across ==, eql?, hash, and uniq
- **WHEN** two `GuestName` instances normalise to the same `#display` (e.g. `GuestName.new("alice")` and `GuestName.new("Alice")`)
- **THEN** they are `==` and `eql?`, return the same `#hash`, resolve as the same Hash key, and de-duplicate to one element under `Array#uniq`
- Maps to: `spec/domain/guest_name_spec.rb`
