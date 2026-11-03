# Spec Delta

## ADDED Requirements

### Requirement: GuestName is a value object with a consistent equality contract
`GuestName` SHALL implement `==`, `eql?`, and `hash` consistently so that two
instances whose normalised `#display` values are equal compare equal under all
three. Equal names MUST therefore behave as the same key in a Hash, as the same
member in a Set, and collapse to a single element under `Array#uniq`.

#### Scenario: Equal names agree across ==, eql?, hash, and uniq
- **WHEN** two `GuestName` instances normalise to the same `#display` (e.g. `GuestName.new("alice")` and `GuestName.new("Alice")`)
- **THEN** they are `==` and `eql?`, return the same `#hash`, resolve as the same Hash key, and de-duplicate to one element under `Array#uniq`
- Maps to: `spec/domain/guest_name_spec.rb`
