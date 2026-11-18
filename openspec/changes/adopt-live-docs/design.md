## Context

greeter-docs will read, per repo, requirement slugs and test statuses. The slug
rule and the `greeterhq.repo-trace.v1` schema are shared across all greeterHQ
repos; this design decides how greeter-core implements them. `lib/` is
untouched, so there is no public API change (no before/after API to show).

## Decisions

### Slug helper
`spec/support/slug.rb` defines `RepoTrace::Slug.call(text)`:
`text.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')`. No camel-case
splitting. `spec/support/slug_spec.rb` asserts this table, plus every real
requirement and scenario heading in `openspec/specs/**` (each against a
hand-written slug in the spec, not computed with the function under test):

| Heading text | Slug |
|---|---|
| Greets a named guest | greets-a-named-guest |
| Surfaces control/escape characters as an error | surfaces-control-escape-characters-as-an-error |
| Greet a guest and return a running count | greet-a-guest-and-return-a-running-count |
| Clock port declares an unimplemented #now | clock-port-declares-an-unimplemented-now |
| GreetingPresenter port declares an unimplemented #present | greetingpresenter-port-declares-an-unimplemented-present |
| Base Clock#now raises NotImplementedError | base-clock-now-raises-notimplementederror |
| Rejects a name longer than 64 characters | rejects-a-name-longer-than-64-characters |
| Completes #greet in under 5 ms at p99 | completes-greet-in-under-5-ms-at-p99 |
| Equal names agree across ==, eql?, hash, and uniq | equal-names-agree-across-eql-hash-and-uniq |
| `"  --Leading and trailing!!  "` | leading-and-trailing |

### Trace-check reads tags statically
`spec/trace_check_spec.rb` collects tags by scanning `spec/**/*.rb` text, not by
reading loaded RSpec metadata, because `spec/benchmarks/*_bench.rb` is not loaded
by the default run. The scan regex is
`requirement:\s*'([^']+)',\s*scenario:\s*'([^']+)'` (the `\s` allows the pair to
wrap across lines; order is always requirement then scenario). The scan skips
`spec/fixtures/**`, so fixture tags and tag text used by other specs never count
as real tags. Logic lives in `spec/support/trace_check.rb` as
`RepoTrace::Check.call(spec_glob:, example_glob:, change_glob: nil, exclude_glob: nil)`,
returning problem strings. The real-repo example passes
`spec_glob: 'openspec/specs/**/spec.md'`,
`change_glob: 'openspec/changes/**/specs/**/spec.md'`,
`example_glob: 'spec/**/*.rb'`, `exclude_glob: 'spec/fixtures/**/*'`.
- Requirement headings: `^### Requirement:\s*(.+)$`; scenario headings:
  `^#### Scenario:\s*(.+)$`, attached to the requirement above them.
- In-flight changes: files matched by `change_glob` are read too, skipping any
  path under `changes/archive/`. In those files only headings inside
  `## ADDED Requirements` and `## MODIFIED Requirements` sections count;
  `## REMOVED` and `## RENAMED` sections are ignored. Without this, CI cannot
  go green before the merge, and the merge must come before the archive. The
  same requirement slug may appear in a main spec and in a MODIFIED delta;
  their scenarios are combined. Delta requirements need a tagged example too.
  The test globs use `changes/**` on purpose, so the archive skip is tested.
- Requirement slugs are matched across all spec files. Scenario slugs are matched
  only within their requirement. A scenario slug equal to its requirement's slug
  is valid (some existing scenarios repeat their requirement text).
- Problems: `requirement "<slug>" (<spec.md>) has no tagged example`;
  `example tagged requirement "<slug>" (<file>:<line>) matches no requirement heading`;
  `example scenario "<slug>" (<file>:<line>) is not a scenario of requirement "<slug>"`.
- Fixtures in `spec/fixtures/trace_check/`: `specs/alpha/spec.md` (covered,
  uncovered and same-text requirements), `changes/in-flight-change/...` (ADDED,
  MODIFIED, REMOVED and RENAMED sections), `changes/archive/2026-01-01-archived-change/...`
  (an archived-only requirement), and `examples/*.rb` tag lists that do not end
  in `_spec.rb`. One example runs the check on the real repo.

### Formatter
`spec/support/repo_trace_formatter.rb` defines `RepoTraceFormatter`, registered
for `:example_passed, :example_failed, :example_pending, :dump_summary`. For each
example with both `requirement` and `scenario` metadata it records
`{requirement, scenario, status, source: 'rspec', location}`.
- Status: passed, failed. RSpec reports both skip and pending as
  `:example_pending`. `example.metadata[:skip]` truthy means `skipped`; otherwise
  `example.execution_result.pending_message` present means `pending`. Both cases
  are tested.
- Tags come from `example.metadata`, which includes metadata inherited from
  enclosing groups, so a shared example included inside a tagged `context`
  carries that context's tags. `it_behaves_like` itself cannot carry tags: in
  rspec-core 3.13 its extra arguments go to the shared block, not to metadata.
- `location`: `example.location` relative to the repo root. Shared examples
  (`it_behaves_like`) report the same location for every invocation; results
  with the same requirement, scenario and location collapse to one, keeping the
  worst status (failed, pending, skipped, passed).
- Errors: a malformed value raises with a message starting `invalid requirement`,
  `invalid scenario`, `invalid location`, `invalid sha` or `invalid run_id`. The
  message names the field only and never echoes the value.
- Results are sorted by location, then requirement, then scenario.
- Output path: `ENV['REPO_TRACE_PATH']`, default `tmp/repo-trace.json`; parent
  directory is created. `tmp/` is already git-ignored.
- `sha`: `ENV['GITHUB_SHA']`, else `git rev-parse HEAD`. `run_id`:
  `ENV['GITHUB_RUN_ID']` or `nil`. `recorded_at`: `Time.now.utc.iso8601`
  (the no-`Time.now` rule applies to `lib/` only). Env, clock and root are
  constructor inputs so the spec can control them.
- It reads only slug metadata, status, location. It never reads description,
  full_description, exception or message, so guest names cannot leak.
- Loaded via `.rspec` (`--require support/repo_trace_formatter`); it only writes
  when selected with `--format RepoTraceFormatter`.
- The formatter spec runs fixture example files (`spec/fixtures/repo_trace/*.rb`:
  statuses, privacy, malformed tag, shared example, wrapped shared example) in
  a subprocess (`rspec --options /dev/null --require
  <root>/spec/support/repo_trace_formatter.rb --format RepoTraceFormatter <fixture>`)
  with `REPO_TRACE_PATH` in a temp dir, then reads the JSON.

### Merge script
`bin/merge-repo-trace OUT IN_A IN_B`, stdlib only (`json`, `time`), with
`# frozen_string_literal: true`. `spec/bin/repo_trace_merge_spec.rb` runs it as
a subprocess (`ruby bin/merge-repo-trace OUT IN_A IN_B`), the way CI calls it.
Error messages: `<field> differs` for schema, repo, sha and run_id; shape errors
name the input file and the field or key; a duplicate names the requirement and
location. It:
- fails (exit 1, message on stderr, no output written) if `schema`, `repo`,
  `sha` or `run_id` differ (both come from the same workflow run, so they must
  match; `null` equals only `null`), or if a `(requirement, scenario, location)`
  triple appears in both inputs;
- otherwise writes the shared schema/repo/sha/run_id, the later `recorded_at`,
  and all results sorted as above.
It is not part of the gem (`lib/` and the gemspec file list are unchanged;
confirm at apply that the gemspec does not glob `bin/`).

### CI
- `on:` adds `schedule: - cron: '17 6 * * 1'`.
- Gate (used by `trace` and `notify-docs`):
  `github.event_name == 'schedule' || (github.event_name == 'push' && github.ref == 'refs/heads/main')`.
- `functional`: `REPO_TRACE_PATH=tmp/repo-trace-functional.json bundle exec rspec --format progress --format RepoTraceFormatter`,
  then `actions/upload-artifact` `repo-trace-functional`, `retention-days: 1`,
  `if-no-files-found: error`.
- `performance`: `REPO_TRACE_PATH=tmp/repo-trace-performance.json bundle exec rspec spec/benchmarks --pattern 'spec/benchmarks/**/*_bench.rb' --format progress --format RepoTraceFormatter`,
  then upload `repo-trace-performance`, `retention-days: 1`. The benchmark runs
  only here. This fixes an existing bug: today's `rspec spec/benchmarks/`
  applies the default `*_spec.rb` pattern, reports "No examples found" and
  passes, so the latency requirement was never checked in CI.
  `ci_workflow_spec` takes this rspec command from `ci.yml` (dropping leading
  `VAR=value` words, with `REPO_TRACE_PATH` set to a temp file), runs it with
  `--dry-run`, and expects at least one example and no "No examples found".
- `trace`: `needs: [functional, performance]`, `if: <gate>`,
  `permissions: {contents: read}`. Steps: checkout, `ruby/setup-ruby` (no
  bundler-cache; stdlib only), `actions/download-artifact` for both names,
  `bin/merge-repo-trace tmp/repo-trace.json <functional> <performance>`, then
  upload `repo-trace` with `retention-days: 90`. Downloaded files are placed in
  separate directories so names cannot collide.
- `notify-docs`: `needs: trace`, `if: <gate>`, `permissions: {}`. Steps:
  `actions/create-github-app-token@v3` with `client-id: ${{ vars.DISPATCH_APP_CLIENT_ID }}`,
  `private-key: ${{ secrets.DISPATCH_APP_PRIVATE_KEY }}`, `owner: greeterhq`,
  `repositories: greeter-docs`; then
  `gh api repos/greeterhq/greeter-docs/dispatches -f event_type=docs-refresh -f client_payload[repo]=greeter-core`
  with `GH_TOKEN` from the step output. No fallback if the credentials are
  missing; the job fails.
- `publish` keeps `needs: [functional, performance]` and gets
  `if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')`.
- Consequence: `trace` needs both jobs to succeed, so a red test run on `main`
  publishes no trace and sends no `docs-refresh`.
- `spec/ci_workflow_spec.rb` parses `ci.yml` with `YAML.safe_load` (the file
  quotes `"on"`, so the key loads as a string) and asserts the structure above.

### Tagging existing specs
Tag every example whose assertion verifies a scenario, adding
`requirement:`/`scenario:` to the `it` or `describe` line only. Groups of
`it_behaves_like` lines are wrapped, unchanged, in a
`context '<requirement text>', requirement: '...', scenario: '...' do ... end`
that carries the tags. Examples that verify no scenario stay untagged. Mapping
as written in the red tests:

| Spec file | Examples | Requirement / scenario |
|---|---|---|
| `domain/guest_name_spec.rb` | `#display` "strips surrounding whitespace and title-cases" | validates-and-normalises-a-guest-name / normalises-whitespace-and-casing |
| | context around `it_behaves_like` `''`, `'   '` | rejects-an-empty-or-whitespace-only-name / same slug |
| | context around `it_behaves_like` `'a' * 65` | rejects-a-name-longer-than-64-characters / same slug |
| | context around `it_behaves_like` `"\e[31m"`, `"Alice\n"`; null byte and DEL `it`s | rejects-names-containing-control-or-escape-characters / rejects-a-name-containing-a-control-or-escape-character |
| | equality example | guestname-is-a-value-object-with-a-consistent-equality-contract / equal-names-agree-across-eql-hash-and-uniq |
| `domain/greeting_spec.rb` | the three examples | greeting-is-an-immutable-value-object / greeting-holds-its-fields-and-is-frozen |
| `domain/greet_guest_spec.rb` | "returns a Greeting", "sets greeted_at", "sets guest_name" | greetingservice-composes-a-greeting-from-an-injected-clock / returns-a-greeting-for-a-valid-name |
| | the three `propagates InvalidGuestName` examples | same requirement / propagates-invalidguestname-for-bad-input |
| `ports/clock_spec.rb`, `ports/greeting_presenter_spec.rb` | the one example each | the port requirements and their scenarios |
| `benchmarks/greeting_service_bench.rb` | latency example | greeting-construction-stays-within-latency-budget / completes-greet-in-under-5-ms-at-p99 |

Notes: the `it_behaves_like` lines are grouped by scenario because the inputs
belong to different scenarios. Existing `# Scenario:`
comments in the specs are stale and left alone (editing them would break the
tag-only check). `describe '#greet'` is not tagged; it spans several scenarios.
Three of the greeting-core scenarios named in the request repeat their
requirement text; the table above has two (empty-name and 64-character); the
check allows any number.

### Tag-only verification
The check that tagging changed nothing else cannot be the `grep -v` pipeline
alone: for every edited line, the removed `-` line has no tag and would print.
`spec/support/tag_only_diff.rb` defines
`RepoTrace::TagOnlyDiff.call(path:, before:, after:)`, returning problem strings
that name `path` (empty when allowed). Both texts are normalised the same way,
then compared:
1. remove each tagged context wrapper: a
   `context '<text>', requirement: '...', scenario: '...' do` opener (which may
   wrap across lines) and the `end` at the same indentation that closes it;
2. remove `, requirement: '...'` and `, scenario: '...'`;
3. for `path == 'spec/spec_helper.rb'` only, remove the spec/support loader
   block exactly as committed (the two comment lines, the `Dir[...]` line, the
   `require` line and its `end`);
4. remove all whitespace.
Any remaining difference is a problem. So a wrapper is allowed only if the
lines between its opener and `end` are unchanged.
`spec/support/tag_only_diff_spec.rb` covers: tags added (allowed), assertion
changed (fails), wrapper added (allowed), wrapper that also changes a line
inside (fails), loader block in `spec/spec_helper.rb` (allowed), the same block
in another file (fails), and another `spec_helper.rb` change (fails). Fixtures
are `before.rb`/`after.rb` pairs in `spec/fixtures/tag_only/<case>/`.
Known limit: whitespace is removed everywhere, including inside string
literals, so `'   '` changed to `''` would pass. The diff is small enough to
review by eye for that.

Allowed changes in existing files: tag pairs, whitespace, tagged context
wrappers, and in `spec/spec_helper.rb` the support loader block only.
The original grep pipeline is kept as a second, informational listing. New
files are not compared: `spec/ci_workflow_spec.rb`, `spec/fixtures/**`,
`spec/bin/repo_trace_merge_spec.rb`, `spec/trace_check_spec.rb`, and under
`spec/support/`: `slug_spec.rb`, `trace_check` and `tag_only_diff` specs,
`repo_trace_formatter_spec.rb`, plus the implementation files.

### RuboCop exclusions
`.rubocop.yml` gains file-scoped exclusions only, each commented in the file:
- `RSpec/SpecFilePathSuffix`: `spec/fixtures/**/*` (fixtures must not end in
  `_spec.rb`, so the suite never loads them).
- `RSpec/DescribeClass`: the tooling specs (`spec/support/*_spec.rb`,
  `spec/trace_check_spec.rb`, `spec/bin/*_spec.rb`, `spec/ci_workflow_spec.rb`)
  and `spec/fixtures/repo_trace/*.rb`; they test spec-side tooling, not a
  `Greeter::Core` class.
- `RSpec/ExampleLength`: the tooling specs; one aggregate_failures example per
  scenario needs more than five lines.
- `RSpec/MultipleMemoizedHelpers`: `spec/support/*_spec.rb`, `spec/bin/*_spec.rb`
  (temp dir, paths, sha and fixture traces).
- `RSpec/IdenticalEqualityAssertion`, `RSpec/ExpectActual`:
  `spec/fixtures/repo_trace/*.rb` (trivial literal assertions; only the status
  matters).
- `RSpec/ContextWording`: `spec/domain/guest_name_spec.rb` and
  `spec/fixtures/tag_only/**/*` (wrapper contexts are named after the
  requirement, which does not start with when/with/without).
The `.talismanrc` checksum for `.rubocop.yml` is refreshed in task 2.6.

## Security considerations

Reviewed: the formatter, merge script, trace-check, `ci.yml` changes and the
cross-repo dispatch. Trust boundaries: PR code (untrusted, no secrets) versus
`main` and schedule (trusted, has the app key); the trace file (read by
greeter-docs); the dispatch payload (read by greeter-docs).

| # | Finding | Severity | Resolution |
|---|---|---|---|
| S1 | `ci.yml` has no top-level `permissions`, so jobs get the repository default `GITHUB_TOKEN` scope, which may be write-all. | Medium | Add top-level `permissions: {contents: read}`; `publish` keeps its own `id-token: write`; `notify-docs` keeps `{}`. Task 2.7. |
| S2 | The app token could carry every permission the app was granted on greeter-docs. `repository_dispatch` needs only contents write. | Medium | Pass `permission-contents: write` to `actions/create-github-app-token@v3` and scope with `repositories: greeter-docs`. Task 2.7. |
| S3 | Trace values (slugs, sha, run_id) end up in a file greeter-docs renders. Tag text is free-form and `GITHUB_SHA`/`GITHUB_RUN_ID` come from the environment, so the "no guest names" guarantee depends on never writing arbitrary strings. | Medium | The formatter validates before writing: slug `\A[a-z0-9]+(-[a-z0-9]+)*\z`, location `\Aspec/[\w./-]+\.rb:\d+\z`, sha `\A[0-9a-f]{40}\z`, run_id `\A\d+\z`, all `String`; on a violation it raises and writes nothing. `git rev-parse HEAD` runs via an argument array (no shell). Task 2.3. |
| S4 | `bin/merge-repo-trace` ingests downloaded artifacts and writes the file that is published. An unexpected key or value would pass through into `repo-trace`. | Medium | The merge applies the same patterns, allows only the v1 keys, statuses and `source: rspec`, parses with `JSON.parse` (never `JSON.load`), and writes nothing on any error. Task 2.4. |
| S5 | Untrusted `${{ }}` interpolated into `run:` is the usual workflow injection route. The new steps use none. | Low | Pass values through `env` (`GH_TOKEN`), keep the dispatch payload constant, and assert in `ci_workflow_spec` that `trace` and `notify-docs` `run:` steps contain no `${{`. Tasks 1.5, 2.5. |
| S6 | `trace` runs repo code (`bin/merge-repo-trace`) on `main`. A persisted checkout token is unnecessary. | Low | `persist-credentials: false` on the `trace` checkout; permissions stay `contents: read`. Task 2.5. |
| S7 | Artifact handling: `trace` must read only artifacts produced in the same run. | Low | `actions/download-artifact` by name with no `run-id`/cross-run token and no `merge-multiple`; each artifact goes to its own directory. Covered by Task 2.5 and asserted in `ci_workflow_spec`. |
| S8 | Secrets and PRs: `notify-docs` and `trace` cannot run on PRs (gate excludes `pull_request`), and fork PRs receive no secrets. Dispatch payload has no secrets. | None | No change; asserted by the existing gate scenario. |
| S9 | `actions/create-github-app-token@v3` (required by the request) holds the private key and is referenced by major tag, like the other actions in this file. A moved tag would run new code with the key. | Low, accepted | Keep `@v3` as requested. Pinning actions to commit SHAs is left to `add-dependency-scanning` (Dependabot `github-actions`), not decided here. |
| S10 | Consumer side: greeter-docs treats `client_payload[repo]` and the trace as untrusted input (allowlist of repo names, no use in paths or shell, validate the schema). | Info | Out of scope for this repo. Recorded here as a requirement for the greeter-docs change that consumes `docs-refresh`. |
| S11 | Missing dispatch credentials fail `notify-docs` by design (no fallback). | None | Intended. |

No secret is written to the repo, logs or artifacts: the token is a step output
masked by the runner and only reaches `gh` through `GH_TOKEN`. The trace holds
slugs, statuses, locations and run metadata only.

## Risks / trade-offs
- A regex scan can be fooled by a tag in a comment or string. Accepted; it is
  simple and needs no Node or CLI. Fixtures are excluded from the scan.
- Adding tags may push `it` lines over RuboCop's line length. Wrapping is allowed
  (the tag-only check ignores whitespace).
- `notify-docs` fails until the credentials and app installation exist (added by
  the maintainer before merge; no fallback by design).
- Newly archived `live-docs-traceability` requirements become headings the
  trace-check enforces, so its own specs are tagged too.

## Assumptions
- `skipped`/`pending` mapped as above; duplicate-collapse keeps the worst status.
- Merge keeps the later `recorded_at`.
- Artifact file names: `tmp/repo-trace-functional.json`, `tmp/repo-trace-performance.json`.

## Follow-up
- Remove the old `# Scenario:` comments from the existing specs in a later
  change; the `requirement:`/`scenario:` tags replace them. They are left alone
  here because editing them would break the tag-only check.
