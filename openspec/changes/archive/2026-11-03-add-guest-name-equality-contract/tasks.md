# Tasks

## 1. Red tests

- [x] 1.1 In `spec/domain/guest_name_spec.rb`, replaced the five `value equality` examples with one block-form `aggregate_failures` example asserting the full contract (`==`, `eql?`, equal `#hash`, Hash-key lookup, and `Array#uniq` size 1) against the same pair of names, traced with a `# Scenario: Equal names agree across ==, eql?, hash, and uniq` comment (matching the repo's existing comment convention; the `requirement:`/`scenario:` metadata tags belong to the not-yet-implemented `adopt-live-docs` change and were not used). Green against current `lib/`: `bundle exec rspec spec/domain/guest_name_spec.rb` — 25 examples, 0 failures, 100% coverage.

## 2. Spec and docs

- [x] 2.1 Spec delta `openspec/changes/add-guest-name-equality-contract/specs/greeting-core/spec.md` adds the equality-contract requirement with exactly one `####` scenario mapping to `spec/domain/guest_name_spec.rb`. Verified: `openspec validate add-guest-name-equality-contract --strict` passes.
- [x] 2.2 No `lib/` file changed (so no semver bump, no CHANGELOG entry, no consumer-matrix runs). `git diff --name-only -- lib/` is empty; changed paths are `spec/domain/guest_name_spec.rb`, `.rubocop.yml` (scoped lint exclude for the aggregated example), and the new `openspec/changes/` directory.

## 3. Verify and docs

- [x] 3.1 Full suite and linter: `bundle exec rspec` → 25 examples, 0 failures, 100% line/branch coverage; `bundle exec rubocop` → 21 files, no offenses. Benchmarks skipped because `lib/` is unchanged.
- [x] 3.2 `openspec validate --all --strict` passes (3 items: the change, spec/greeting-core, spec/ports) before archiving.

## Workflow follow-up

- Archive the change with `openspec archive add-guest-name-equality-contract` after review, folding the requirement into `openspec/specs/greeting-core/spec.md`.
- Confirm `openspec validate --all --strict` passes after archiving.
