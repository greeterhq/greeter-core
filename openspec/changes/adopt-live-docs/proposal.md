# Proposal

Does not touch `lib/`. No gem release, no semver bump.

## Why

greeter-docs needs to show, per repo, which requirements exist and whether the
tests that verify them passed. Today greeter-core's scenarios map to RSpec
examples only by a "Maps to:" prose line, so nothing machine-readable links a
requirement to a test result, and nothing fails when the two drift apart.

## What Changes

- Define one slug rule (shared by every greeterHQ repo) and implement it as a
  small helper in `spec/support/`.
- Tag every RSpec example that verifies a requirement with
  `requirement: '<slug>', scenario: '<slug>'`. This edits existing files under
  `spec/`. It is the one sanctioned exception to "never edit spec/": it may only
  add `requirement:`/`scenario:` metadata to `it`, `describe` and
  `it_behaves_like` lines, and may not change any assertion, example body or
  example name. A task verifies this mechanically.
- Add `spec/support/repo_trace_formatter.rb`, an RSpec formatter that writes a
  `greeterhq.repo-trace.v1` file (path from `REPO_TRACE_PATH`, default
  `tmp/repo-trace.json`).
- Add `spec/trace_check_spec.rb`, which fails when a requirement heading has no
  tagged example, when an example's requirement slug matches no heading, or when
  its scenario slug is not a scenario of that requirement. It parses the
  markdown directly (no Node, no OpenSpec CLI).
- Add `bin/merge-repo-trace` (stdlib only) that merges two trace files and fails
  on a schema, repo or sha mismatch or a duplicated result.
- CI: `functional` and `performance` each run rspec with the formatter and upload
  a one-day artifact (`repo-trace-functional`, `repo-trace-performance`). On push
  to `main` and on a weekly schedule (`17 6 * * 1`) a `trace` job merges them and
  uploads `repo-trace` (90 days), then `notify-docs` sends `repository_dispatch`
  `docs-refresh` to `greeterhq/greeter-docs`. Pull requests run `functional` and
  `performance` only. `publish` runs only on `v*` tag pushes.

## Capabilities

### New Capabilities
- `live-docs-traceability`: requirement-to-test tagging, the trace-check, the
  repo-trace file contents, the merge of per-job traces, and the CI publication
  of the merged file to greeter-docs.

### Modified Capabilities
<!-- None. greeting-core and ports requirements are unchanged; they only gain tags. -->

## Non-goals

- Any change to `lib/` or to existing requirement text.
- Rendering the docs site (owned by greeter-docs).
- Running the benchmark more than once: `spec/benchmarks` runs only in
  `performance`.
- A fallback when the dispatch credentials are missing: `notify-docs` failing is
  the intended signal.
- Cucumber (this gem has none), dependency scanning (`add-dependency-scanning`),
  and rewording the stale `# Scenario:` comments in existing specs.

## Consumers affected

- greeter-docs: reads artifact `repo-trace` and receives `docs-refresh`. It must
  accept schema `greeterhq.repo-trace.v1`.
- greeter-cli, greeter-http, greeter-acceptance: none. The gem API is unchanged.

## Impact

- `spec/` (tags on existing examples; new `spec/support/`, `spec/bin/`,
  `spec/fixtures/`, new specs), `bin/merge-repo-trace`, `.rspec`.
- `.github/workflows/ci.yml`.
- Repo configuration, to be added by the maintainer before merge:
  `vars.DISPATCH_APP_CLIENT_ID`, `secrets.DISPATCH_APP_PRIVATE_KEY`, and the
  `greeterhq-dispatch` app installed on `greeterhq/greeter-docs`.
- `.talismanrc` checksums for edited tracked files.
