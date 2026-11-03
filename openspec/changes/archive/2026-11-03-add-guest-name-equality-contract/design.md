# Design

## Context

See proposal.md — Why. The equality contract already ships in
`lib/greeter/core/domain/guest_name.rb` (v0.1.1); this change only documents it
as a requirement and aligns the tests with the one-scenario-one-example
invariant. No `lib/` change is in scope.

The public API is unchanged. For reference, `GuestName`'s equality surface is
already:

```ruby
# before == after (unchanged by this change)
def ==(other)
  other.is_a?(GuestName) && display == other.display
end
alias eql? ==

def hash
  [self.class, display].hash
end
```

## Goals / Non-Goals

**Goals:**
- Add a single `greeting-core` requirement capturing the value-object equality
  contract, with exactly one scenario.
- Keep RSpec traceability intact: that scenario maps to exactly one example.

**Non-Goals:**
- Any change to `lib/`. The design deliberately touches only the spec and the
  test file.
- Redefining equality semantics or adding new ones.

## Decisions

**Decision: ADDED, not MODIFIED, requirement.** The equality contract is a new
concern layered onto the existing `greeting-core` capability, not a change to an
existing requirement's behaviour. Per OpenSpec guidance, adding a new concern
without changing existing behaviour uses `## ADDED Requirements`. Alternative
(MODIFIED on the "immutable value object" requirement) was rejected: that
requirement is about `Greeting`, not `GuestName` equality, and MODIFIED with
partial content loses detail at archive time.

**Decision: consolidate five examples into one.** The current `value equality`
group has five `it` blocks (`==`, `eql?`, `hash`, Hash-key lookup, `uniq`). The
invariant is one-scenario-to-one-example, so the five become one example whose
body asserts all five facts against the same pair of names. Alternative (five
scenarios, one per fact) was rejected: they describe a single contract, and
splitting them would invert the "one requirement, cohesive behaviour" guidance
and multiply near-identical scenarios.

**Decision: editing `spec/` is in scope here and permitted.** The project rule
is "never edit `spec/` during apply to make a failing test pass." This
consolidation is a behaviour-preserving refactor planned in the proposal, not a
reaction to a red test — the same five assertions remain, regrouped into one
example. It is called out explicitly so the apply step is not mistaken for the
forbidden pattern.

## Risks / Trade-offs

- [Consolidating examples could lose a specific assertion] → The single example
  must keep all five assertions (`==`, `eql?`, equal `hash`, Hash-key lookup,
  `uniq` size 1). Verified by the example still failing if any one is removed
  from the implementation.
- [A reader wanting per-fact granularity loses five named examples] → Accepted:
  the contract is cohesive, and the one failing example names the contract it
  guards. RSpec output still pinpoints which assertion failed by line.

## Migration Plan

Not applicable. No deployed behaviour changes; no rollback concerns. The spec
delta is archived into `openspec/specs/greeting-core/spec.md` by
`openspec archive` once tasks are complete.
