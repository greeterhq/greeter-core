# Proposal

This change does NOT touch `lib/`. It is spec/docs-only: no semver bump, no
consumer-matrix runs. The behaviour it documents already ships (since v0.1.1).

## Why

`GuestName` is a value object whose `==`, `eql?`, and `hash` were made
consistent in v0.1.1 (commit d3c6b6d) so that equal names behave correctly as
Hash keys and in Sets. That behaviour is asserted by five RSpec examples in
`spec/domain/guest_name_spec.rb` but has no matching requirement in
`openspec/specs/greeting-core/spec.md`. The gem's stated traceability invariant
is that every OpenSpec scenario maps to exactly one RSpec example; right now the
mapping runs backwards — there are examples with no requirement behind them. The
equality contract is observable behaviour that `greeter-cli` and `greeter-http`
can depend on, so it belongs in the spec, not only in the tests.

## What Changes

- Add one requirement to the existing `greeting-core` capability specifying that
  `GuestName` implements `==`, `eql?`, and `hash` consistently: two names whose
  normalised `#display` values are equal compare equal, are `eql?`, share a
  `#hash`, resolve as the same Hash key, and de-duplicate under `Array#uniq`.
- Consolidate the five existing `value equality` RSpec examples into a single
  example that asserts the whole contract, so the one-scenario-maps-to-one-example
  invariant holds. This is a behaviour-preserving test refactor, not a change to
  `lib/`.
- No production code changes. No `lib/` edits. Not a breaking change.

## Capabilities

### New Capabilities

<!-- None. This change adds a requirement to an existing capability. -->

### Modified Capabilities

- `greeting-core`: adds a new requirement for the `GuestName` value-object
  equality contract (`==`/`eql?`/`hash`). Existing requirements are unchanged.

## Impact

- **Specs**: `openspec/specs/greeting-core/spec.md` gains one requirement with
  one scenario (via the delta in this change).
- **Tests**: `spec/domain/guest_name_spec.rb` — the five `value equality`
  examples become one consolidated example mapped to the new scenario. Net
  behaviour under test is unchanged.
- **Code**: none. `lib/greeter/core/domain/guest_name.rb` already implements the
  contract since v0.1.1.
- **APIs**: none changed. `GuestName#==`, `#eql?`, and `#hash` already exist.
- **Dependencies**: none.

## Non-goals

- No change to name validation, normalisation, or any other `GuestName`
  behaviour.
- No `Greeting` or `GreetingService` changes.
- No version bump and no release; this is documentation catching up to shipped
  behaviour.
- No new equality semantics — this documents what the code already does, it does
  not redefine it.

## Consumers affected

- `greeter-cli` and `greeter-http`: no action required. The documented behaviour
  is already present in the `~> 0.1` line they depend on; this change only makes
  the contract explicit in the spec they reference. No consumer-matrix runs are
  needed because `lib/` is untouched.
