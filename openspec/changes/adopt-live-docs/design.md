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
`RepoTrace::Check.call(spec_glob:, example_glob:)`, returning problem strings.
- Requirement headings: `^### Requirement:\s*(.+)$`; scenario headings:
  `^#### Scenario:\s*(.+)$`, attached to the requirement above them.
- Requirement slugs are matched across all spec files. Scenario slugs are matched
  only within their requirement. A scenario slug equal to its requirement's slug
  is valid (some existing scenarios repeat their requirement text).
- Problems: `requirement "<slug>" (<spec.md>) has no tagged example`;
  `example tagged requirement "<slug>" (<file>:<line>) matches no requirement heading`;
  `example scenario "<slug>" (<file>:<line>) is not a scenario of requirement "<slug>"`.
- Fixtures in `spec/fixtures/trace_check/` are `spec.md` files and `.rb` files
  that do not end in `_spec.rb`. One example runs the check on the real repo.

### Formatter
`spec/support/repo_trace_formatter.rb` defines `RepoTraceFormatter`, registered
for `:example_passed, :example_failed, :example_pending, :dump_summary`. For each
example with both `requirement` and `scenario` metadata it records
`{requirement, scenario, status, source: 'rspec', location}`.
- Status: passed, failed. RSpec reports both skip and pending as
  `:example_pending`. `example.metadata[:skip]` truthy means `skipped`; otherwise
  `example.execution_result.pending_message` present means `pending`. Both cases
  are tested.
- `location`: `example.location` relative to the repo root. Shared examples
  (`it_behaves_like`) report the same location for every invocation; results
  with the same requirement, scenario and location collapse to one, keeping the
  worst status (failed, pending, skipped, passed).
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
- The formatter spec runs fixture example files (`spec/fixtures/repo_trace/*.rb`)
  in a subprocess (`ruby -S rspec --options /dev/null --require
  ./spec/support/repo_trace_formatter --format RepoTraceFormatter <fixture>`)
  with `REPO_TRACE_PATH` in a temp dir, then reads the JSON.

### Merge script
`bin/merge-repo-trace OUT IN_A IN_B`, stdlib only (`json`, `time`), with
`# frozen_string_literal: true`. The logic is a `RepoTrace::Merge` class in the
same file, run only when `$PROGRAM_NAME == __FILE__`, so
`spec/bin/repo_trace_merge_spec.rb` can `load` it. It:
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
- `performance`: `REPO_TRACE_PATH=tmp/repo-trace-performance.json bundle exec rspec spec/benchmarks/ --format progress --format RepoTraceFormatter`,
  then upload `repo-trace-performance`, `retention-days: 1`. The benchmark runs
  only here.
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
`requirement:`/`scenario:` to the `it`, `describe` or `it_behaves_like` line
only. Examples that verify no scenario stay untagged. Planned mapping (final
line choice is made at apply, within the rule above):

| Spec file | Examples | Requirement / scenario |
|---|---|---|
| `domain/guest_name_spec.rb` | `#display` "strips surrounding whitespace and title-cases" | validates-and-normalises-a-guest-name / normalises-whitespace-and-casing |
| | `it_behaves_like` `''`, `'   '` | rejects-an-empty-or-whitespace-only-name / same slug |
| | `it_behaves_like` `'a' * 65` | rejects-a-name-longer-than-64-characters / same slug |
| | `it_behaves_like` `"\e[31m"`, `"Alice\n"`, null byte, DEL | rejects-names-containing-control-or-escape-characters / rejects-a-name-containing-a-control-or-escape-character |
| | equality example | guestname-is-a-value-object-with-a-consistent-equality-contract / equal-names-agree-across-eql-hash-and-uniq |
| `domain/greeting_spec.rb` | the three examples | greeting-is-an-immutable-value-object / greeting-holds-its-fields-and-is-frozen |
| `domain/greet_guest_spec.rb` | "returns a Greeting", "sets greeted_at", "sets guest_name" | greetingservice-composes-a-greeting-from-an-injected-clock / returns-a-greeting-for-a-valid-name |
| | the three `propagates InvalidGuestName` examples | same requirement / propagates-invalidguestname-for-bad-input |
| `ports/clock_spec.rb`, `ports/greeting_presenter_spec.rb` | the one example each | the port requirements and their scenarios |
| `benchmarks/greeting_service_bench.rb` | latency example | greeting-construction-stays-within-latency-budget / completes-greet-in-under-5-ms-at-p99 |

Notes: the shared example's `it_behaves_like` group is tagged per invocation
because the four inputs belong to different scenarios. Existing `# Scenario:`
comments in the specs are stale and left alone (editing them would break the
tag-only check). `describe '#greet'` is not tagged; it spans several scenarios.
Three of the greeting-core scenarios named in the request repeat their
requirement text; the table above has two (empty-name and 64-character); the
check allows any number.

### Tag-only verification
The check that tagging changed nothing else cannot be the `grep -v` pipeline
alone: for every edited line, the removed `-` line has no tag and would print.
The task therefore compares each modified spec file at `main` with the working
file after deleting `, requirement: '...'` and `, scenario: '...'` and all
whitespace; any difference fails. The original grep pipeline is kept as a
second, informational listing. New files are listed here and are not compared:
`spec/ci_workflow_spec.rb`, `spec/fixtures/**`, `spec/bin/repo_trace_merge_spec.rb`,
`spec/support/slug.rb`, `slug_spec.rb`, `trace_check.rb`, `repo_trace_formatter.rb`,
`repo_trace_formatter_spec.rb`, `spec/trace_check_spec.rb`.

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

## Follow-up
- Remove the old `# Scenario:` comments from the existing specs in a later
  change; the `requirement:`/`scenario:` tags replace them. They are left alone
  here because editing them would break the tag-only check.
- Artifact file names: `tmp/repo-trace-functional.json`, `tmp/repo-trace-performance.json`.
