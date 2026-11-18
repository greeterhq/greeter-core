## 1. Red tests

Spec edits in this change happen with `tests-open` active and finish with `tests-close`.

- [x] 1.1 Write `spec/support/slug_spec.rb`: the ten-row slug table plus every real heading in `openspec/specs/**` and the `live-docs-traceability` delta, and a check that every heading in `openspec/specs/**` has a hand-written row; show red with NameError
- [x] 1.2 Write `spec/trace_check_spec.rb` and fixtures in `spec/fixtures/trace_check/` (covered; requirement without example; unknown requirement slug; scenario slug under the wrong requirement; scenario slug equal to its requirement slug); in-flight change deltas (ADDED/MODIFIED slug known; slug only in an archived change unknown; REMOVED/RENAMED headings ignored), using a `changes/**` glob so the archive skip is tested; plus one real-repo example passing `change_glob:` and `exclude_glob:`; show red
- [x] 1.3 Write `spec/support/repo_trace_formatter_spec.rb` and `spec/fixtures/repo_trace/*.rb`: v1 fields and passed/failed, skip -> skipped and pending -> pending (separate examples), sha/run_id from env and from `git rev-parse HEAD`, no description (`Alice Smith`) and exact result keys, shared-example collapse, a shared example inside a tagged context carries the context's tags, malformed slug/sha/run_id refused with no file written (S3); show red
- [x] 1.4 Write `spec/bin/repo_trace_merge_spec.rb` (subprocess): merge of disjoint traces; mismatch of schema, repo, sha (no output file written); run_id mismatch (including null vs non-null); duplicated result; later `recorded_at` kept; unknown keys, bad status/source/patterns rejected with no output file (S4); show red
- [x] 1.5 Write `spec/ci_workflow_spec.rb`: the five CI scenarios in the delta spec, including top-level `permissions`, token scope, no `${{` in `trace`/`notify-docs` `run:` steps, `persist-credentials: false`, and no `run-id`/`merge-multiple` on downloads (S1, S2, S5-S7); plus the performance job's rspec command from `ci.yml` run with `--dry-run`, expecting at least one example and no "No examples found" (red today: `rspec spec/benchmarks/` finds no files); show red
- [x] 1.6 Tag the existing examples per the mapping in design.md in `spec/domain/guest_name_spec.rb` (the `it_behaves_like` groups wrapped, unchanged, in tagged contexts), `greeting_spec.rb`, `greet_guest_spec.rb`, `spec/ports/clock_spec.rb`, `greeting_presenter_spec.rb`, `spec/benchmarks/greeting_service_bench.rb`; tag the new specs per the delta spec
- [x] 1.7 Write `spec/support/tag_only_diff_spec.rb` and `spec/fixtures/tag_only/<case>/{before,after}.rb`: tags added (allowed), assertion changed (fails), tagged context wrapper added (allowed), wrapper that also changes a line inside (fails), spec_helper loader block in `spec/spec_helper.rb` (allowed), the same block elsewhere (fails), another spec_helper change (fails); show red
- [x] 1.8 Add the spec/support loader block to `spec/spec_helper.rb`, and the commented, file-scoped RuboCop exclusions listed in design.md to `.rubocop.yml`
- [ ] 1.9 Commit as `test(adopt-live-docs): ...` with the failing output

## 2. Implementation

- [ ] 2.1 `spec/support/slug.rb` (`RepoTrace::Slug`)
- [ ] 2.2 `spec/support/trace_check.rb` (`RepoTrace::Check`, with `change_glob:` reading only ADDED/MODIFIED sections of non-archived changes, and `exclude_glob:`)
- [ ] 2.3 `spec/support/repo_trace_formatter.rb`; add `--require support/repo_trace_formatter` to `.rspec`; validate slug, location, sha and run_id patterns before writing, and run `git rev-parse HEAD` with an argument array, no shell (S3)
- [ ] 2.4 `bin/merge-repo-trace` (stdlib only, executable bit, frozen string literal); `JSON.parse` only, allowlisted keys, statuses, `source` and value patterns, no output on error (S4); confirm the gemspec does not package `bin/`
- [ ] 2.5 Update `.github/workflows/ci.yml`: schedule, formatter and artifact upload in `functional`; `performance` runs `REPO_TRACE_PATH=tmp/repo-trace-performance.json bundle exec rspec spec/benchmarks --pattern 'spec/benchmarks/**/*_bench.rb' --format progress --format RepoTraceFormatter` and uploads its trace; `trace` job (`persist-credentials: false`, same-run downloads by name, no `run-id`/`merge-multiple`), `notify-docs` job (token via `env: GH_TOKEN`, constant payload, no `${{` in `run:`), explicit `publish` condition (S5-S7)
- [ ] 2.6 Update `.talismanrc` checksums for edited tracked files (including `.rubocop.yml` and `spec/domain/guest_name_spec.rb`)
- [ ] 2.7 In `ci.yml` add top-level `permissions: {contents: read}` (keep `publish` with `id-token: write`, `contents: read`; `notify-docs` with `{}`) and pass `permission-contents: write` to `actions/create-github-app-token@v3` (S1, S2)
- [ ] 2.8 `spec/support/tag_only_diff.rb` (`RepoTrace::TagOnlyDiff`), normalising as described in design.md

## 3. Verify and docs

- [ ] 3.1 `bundle exec rspec`, then `REPO_TRACE_PATH=tmp/repo-trace-functional.json bundle exec rspec --format RepoTraceFormatter` and `REPO_TRACE_PATH=tmp/repo-trace-performance.json bundle exec rspec spec/benchmarks --pattern 'spec/benchmarks/**/*_bench.rb' --format RepoTraceFormatter`; run `bin/merge-repo-trace` on them and inspect the merged file (every requirement present, including the latency requirement; no descriptions)
- [ ] 3.2 `bundle exec rubocop` (including `bin/merge-repo-trace`)
- [ ] 3.3 Tag-only check on modified spec files (must print nothing). It allows tag pairs, whitespace, tagged context wrappers around unchanged lines, and in `spec/spec_helper.rb` the support loader block only:
  ```
  for f in $(git diff main --name-only --diff-filter=M -- spec ':!spec/support' ':!spec/fixtures'); do
    ruby -r ./spec/support/tag_only_diff -e 'p = RepoTrace::TagOnlyDiff.call(path: ARGV[0], before: `git show main:#{ARGV[0]}`, after: File.read(ARGV[0])); abort p.join("\n") unless p.empty?' "$f"
  done
  ```
- [ ] 3.4 Informational: run the requested pipeline `git diff main -- spec ':!spec/support' ':!spec/trace_check_spec.rb' ':!spec/**/slug*_spec.rb' ':!spec/**/repo_trace*_spec.rb' | grep '^[-+]' | grep -v '^[-+][-+]' | grep -v 'requirement:' | grep -v 'scenario:'`. It lists only the replaced original lines, the wrapper `context`/`end` lines, the spec_helper loader block, and the new files named in design.md (`spec/ci_workflow_spec.rb`, `spec/fixtures/**`); anything else is a defect
- [ ] 3.5 `openspec validate adopt-live-docs --strict`, then after archive `openspec validate --all --strict`
- [ ] 3.6 Maintainer confirms the greeterhq-dispatch app grants only contents write on greeter-docs, and that the greeter-docs consumer change allowlists `client_payload[repo]` and validates the trace schema (S10). Also confirms before merge: `vars.DISPATCH_APP_CLIENT_ID`, `secrets.DISPATCH_APP_PRIVATE_KEY`, `greeterhq-dispatch` installed on greeter-docs (no fallback is added)
- [ ] 3.7 README note on the `repo-trace` artifact; no CHANGELOG entry (`lib/` unchanged)
