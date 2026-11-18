## ADDED Requirements

### Requirement: Every requirement has a tagged example
Every known `### Requirement:` heading SHALL be covered by at least one RSpec
example tagged `requirement: '<slug>'`. A slug is the heading text lowercased,
each run of characters other than a-z and 0-9 replaced by one `-`, and `-`
trimmed from both ends; scenario slugs come the same way from `#### Scenario:`
headings. When a requirement has no tagged example, the suite SHALL fail naming
the requirement and its spec file.

#### Scenario: Slug rule turns headings into slugs
- **WHEN** the slug function is given the headings in the slug table (for example `Greets a named guest`, `Base Clock#now raises NotImplementedError`, `Equal names agree across ==, eql?, hash, and uniq`, `"  --Leading and trailing!!  "`, and this repo's real requirement and scenario headings)
- **THEN** it returns `greets-a-named-guest`, `base-clock-now-raises-notimplementederror`, `equal-names-agree-across-eql-hash-and-uniq`, `leading-and-trailing`, and the expected slug for every other row, with no camel-case splitting
- Maps to: `spec/support/slug_spec.rb`

#### Scenario: Requirement with no tagged example fails and is named
- **WHEN** the trace-check runs against a fixture `spec.md` containing a requirement that no example is tagged with
- **THEN** it fails with a message naming that requirement's slug and the fixture file
- Maps to: `spec/trace_check_spec.rb`

### Requirement: Tagged examples must match a requirement and scenario
An RSpec example whose `requirement:` slug matches no known requirement SHALL
cause the suite to fail naming the slug and the example's file. Known headings
come from `openspec/specs/**/spec.md` and from the ADDED and MODIFIED sections
of changes that are not archived. An example whose `scenario:` slug is not a
scenario of its requirement SHALL also fail. A scenario slug may equal its
requirement's slug.

#### Scenario: Unknown requirement slug fails and is named
- **WHEN** the trace-check runs with an example tagged with the requirement slug `no-such-requirement`
- **THEN** it fails with a message naming `no-such-requirement` and the example's file
- Maps to: `spec/trace_check_spec.rb`

#### Scenario: Scenario slug is matched only within its requirement
- **WHEN** the trace-check runs with an example whose scenario slug exists only under a different requirement, and another whose scenario slug equals its own requirement's slug
- **THEN** it fails naming the first example's scenario, requirement and file, and reports no problem for the second
- Maps to: `spec/trace_check_spec.rb`

#### Scenario: Requirements in in-flight changes are known
- **WHEN** the trace-check also reads change deltas and an example is tagged with a requirement or scenario found only in an ADDED or MODIFIED section of a change that is not archived, or found only in an archived change, or only in a REMOVED or RENAMED section
- **THEN** the first is known and reports no problem, and the others are reported as unknown with the example's file and line
- Maps to: `spec/trace_check_spec.rb`

### Requirement: Repo trace contains only slugs, statuses, locations and run metadata
The formatter SHALL write a file in schema `greeterhq.repo-trace.v1` with one
result per example tagged with both `requirement` and `scenario`. It SHALL NOT
write example descriptions, failure messages, or any other field, because
descriptions can contain guest names.

#### Scenario: Formatter writes the v1 document
- **WHEN** a suite with one passing and one failing tagged example is run with the formatter
- **THEN** the file has `schema` `greeterhq.repo-trace.v1`, `repo` `greeter-core`, `sha` (`GITHUB_SHA` or `git rev-parse HEAD`), `recorded_at` (UTC ISO 8601), `run_id` (`GITHUB_RUN_ID` or `null`), and two `results` with statuses `passed` and `failed`, `source` `rspec`, and `spec/...rb:LINE` locations
- Maps to: `spec/support/repo_trace_formatter_spec.rb`

#### Scenario: Formatter tells skipped from pending
- **WHEN** a suite with one example marked `skip` and one marked `pending`, both tagged, is run with the formatter
- **THEN** the skipped example has status `skipped` and the pending example has status `pending`
- Maps to: `spec/support/repo_trace_formatter_spec.rb`

#### Scenario: Formatter refuses malformed values
- **WHEN** a tagged example has a requirement or scenario value that is not a lowercase slug (for example `Alice Smith`), or the environment supplies a `GITHUB_SHA` that is not 40 hex characters or a `GITHUB_RUN_ID` that is not digits
- **THEN** the formatter raises an error naming the field and writes no file
- Maps to: `spec/support/repo_trace_formatter_spec.rb`

#### Scenario: Formatter omits descriptions
- **WHEN** a tagged example whose description contains `Alice Smith` is run with the formatter
- **THEN** the written file does not contain `Alice Smith` and each result has exactly the keys `requirement`, `scenario`, `status`, `source`, `location`
- Maps to: `spec/support/repo_trace_formatter_spec.rb`

### Requirement: Per-job traces merge into one trace
`bin/merge-repo-trace` SHALL merge the functional and performance trace files
into one `greeterhq.repo-trace.v1` file containing every result from both. It
SHALL fail, writing nothing, when the inputs differ in `schema`, `repo`, `sha` or
`run_id`, or when the same result appears in both.

#### Scenario: Merge combines both traces
- **WHEN** two valid trace files with the same schema, repo and sha and disjoint results are merged
- **THEN** the output has the same schema, repo, sha and `run_id`, the later of the two `recorded_at` values, and all results from both files
- Maps to: `spec/bin/repo_trace_merge_spec.rb`

#### Scenario: Merge rejects mismatched inputs
- **WHEN** the two files differ in `schema`, in `repo`, or in `sha`
- **THEN** the merge exits non-zero with a message naming the differing field and writes no output file
- Maps to: `spec/bin/repo_trace_merge_spec.rb`

#### Scenario: Merge rejects differing run ids
- **WHEN** the two files have different `run_id` values (including one `null` and one non-null)
- **THEN** the merge exits non-zero with a message naming `run_id` and writes no output file
- Maps to: `spec/bin/repo_trace_merge_spec.rb`

#### Scenario: Merge rejects inputs outside the v1 shape
- **WHEN** an input has an unknown top-level key, a result with an extra key, a `status` outside `passed|failed|pending|skipped`, a `source` other than `rspec`, or a requirement, scenario or location that does not match its pattern
- **THEN** the merge exits non-zero naming the file and field and writes no output file
- Maps to: `spec/bin/repo_trace_merge_spec.rb`

#### Scenario: Merge rejects a duplicated result
- **WHEN** the same requirement, scenario and location appear in both files
- **THEN** the merge exits non-zero with a message naming that requirement and location and writes no output file
- Maps to: `spec/bin/repo_trace_merge_spec.rb`

### Requirement: CI publishes the trace on main and weekly
CI SHALL run rspec with the formatter in `functional` and `performance` on every
push and pull request. On push to `main` and on a weekly schedule only, it SHALL
merge and upload the trace as artifact `repo-trace` and send
`repository_dispatch` `docs-refresh` to `greeterhq/greeter-docs`. `publish`
SHALL run only on `v*` tag pushes.

#### Scenario: Functional and performance upload their own traces
- **WHEN** `.github/workflows/ci.yml` is parsed
- **THEN** `functional` runs the formatter and uploads `repo-trace-functional` with `retention-days: 1`, `performance` runs the formatter writing `tmp/repo-trace-performance.json` and uploads `repo-trace-performance` with `retention-days: 1`, and the performance job's rspec command, run with `--dry-run`, selects at least one example
- Maps to: `spec/ci_workflow_spec.rb`

#### Scenario: Trace job merges and uploads on main and schedule
- **WHEN** `.github/workflows/ci.yml` is parsed
- **THEN** the schedule is `17 6 * * 1`, and `trace` has `needs: [functional, performance]`, `permissions: {contents: read}`, the gate `github.event_name == 'schedule' || (github.event_name == 'push' && github.ref == 'refs/heads/main')`, runs `bin/merge-repo-trace`, and uploads `repo-trace` with `retention-days: 90`
- Maps to: `spec/ci_workflow_spec.rb`

#### Scenario: Notify-docs dispatches docs-refresh
- **WHEN** `.github/workflows/ci.yml` is parsed
- **THEN** `notify-docs` has `needs: trace`, `permissions: {}`, the same gate, a token from `actions/create-github-app-token@v3` (client-id `vars.DISPATCH_APP_CLIENT_ID`, private-key `secrets.DISPATCH_APP_PRIVATE_KEY`, owner `greeterhq`, repository `greeter-docs`), and a `docs-refresh` dispatch with `client_payload[repo]=greeter-core`
- Maps to: `spec/ci_workflow_spec.rb`

#### Scenario: Workflow credentials are least-privilege
- **WHEN** `.github/workflows/ci.yml` is parsed
- **THEN** the workflow has top-level `permissions: {contents: read}`, the app token step requests only `permission-contents: write` and passes through `GH_TOKEN` in `env`, no `run:` step of `trace` or `notify-docs` contains a `${{` expression, the `trace` checkout sets `persist-credentials: false`, and the `trace` download steps set neither `run-id` nor `merge-multiple`
- Maps to: `spec/ci_workflow_spec.rb`

#### Scenario: Only tag pushes publish
- **WHEN** `.github/workflows/ci.yml` is parsed
- **THEN** the `publish` job runs only when `github.event_name == 'push'` and the ref starts with `refs/tags/v`, so it does not run on `schedule` or `pull_request`, and the gate on `trace` and `notify-docs` excludes `pull_request`
- Maps to: `spec/ci_workflow_spec.rb`
