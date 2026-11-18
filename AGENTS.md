# Project conventions — greeter-core

## What this is

`greeter-core` is the pure domain + ports gem for the Greeter system, namespace
`Greeter::Core`. It has **no adapters and no I/O**. Consuming applications
(e.g. `greeter-cli`) depend on this gem and supply the adapters that wire it to
the outside world.

## Architecture: two layers only

| Layer | Path | Namespace | Rules |
|---|---|---|---|
| Domain | `lib/greeter/core/domain` | `Greeter::Core::Domain` | Pure Ruby, zero gems, zero I/O, no AWS, no `Time.now` |
| Ports | `lib/greeter/core/ports` | `Greeter::Core::Ports` | Abstract interfaces (driving + driven); unimplemented methods raise `NotImplementedError` |

Test doubles (`FakeClock`, `FixedClock`) ship under
`lib/greeter/core/testing` (`Greeter::Core::Testing`) and are loaded on demand
with `require 'greeter/core/testing'` — never from the production load path
(`require 'greeter/core'`).

Adapters (CLI, HTTP/Lambda, DynamoDB, `SystemClock`) do **not** belong in this
gem. If a thing performs I/O, it lives in a consuming app.

## Dependency rule

Dependencies point **inward only**. The domain must not reference the ports'
concrete implementations, and nothing in this gem may reference an adapter.

## Dependency injection

All collaborators are injected via constructor keyword arguments. No globals, no
singletons, no `require` of adapter files from domain files.

## TDD

Write the failing RSpec example before the implementation, in the same commit.

## OpenSpec ↔ RSpec traceability

This gem has **no Cucumber**. Its behaviour is exercised without any adapter, so
every OpenSpec spec scenario maps to exactly one RSpec example, and each
scenario names its target spec file (see `openspec/specs/*/spec.md`). When a
consuming app observes a core rule through an adapter (e.g. a CLI exit code for
an invalid name), that observable behaviour is specified in the app's OpenSpec,
not duplicated here — this gem owns the rule; the app references it.

## Toolchain

- Ruby 3.3.x: CI uses the latest 3.3 patch; `.ruby-version` pins 3.3.13 for
  local development. No exact `ruby` directive in the Gemfile.
- `# frozen_string_literal: true` on every file
- RuboCop clean (no offenses)
