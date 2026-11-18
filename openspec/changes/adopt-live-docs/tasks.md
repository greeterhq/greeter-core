## 1. Red tests

Spec edits in this change happen with `tests-open` active and finish with `tests-close`.

- [ ] 1.1 Write `spec/support/slug_spec.rb`: the ten-row slug table plus every real heading in `openspec/specs/**`; show red with NameError
- [ ] 1.2 Write `spec/trace_check_spec.rb` and fixtures in `spec/fixtures/trace_check/` (covered; requirement without example; unknown requirement slug; scenario slug under the wrong requirement; scenario slug equal to its requirement slug); plus one real-repo example; show red
- [ ] 1.3 Write `spec/support/repo_trace_formatter_spec.rb` and `spec/fixtures/repo_trace/*.rb`: v1 fields and passed/failed, skip -> skipped and pending -> pending (separate examples), sha/run_id from env and from `git rev-parse HEAD`, no description (`Alice Smith`) and exact result keys, shared-example collapse, malformed slug/sha/run_id refused with no file written (S3); show red
- [ ] 1.4 Write `spec/bin/repo_trace_merge_spec.rb`: merge of disjoint traces; mismatch of schema, repo, sha (no output file written); run_id mismatch (including null vs non-null); duplicated result; later `recorded_at` kept; unknown keys, bad status/source/patterns rejected with no output file (S4); show red
- [ ] 1.5 Write `spec/ci_workflow_spec.rb`: the five CI scenarios in the delta spec, including top-level `permissions`, token scope, no `${{` in `trace`/`notify-docs` `run:` steps, `persist-credentials: false`, and no `run-id`/`merge-multiple` on downloads (S1, S2, S5-S7); show red
- [ ] 1.6 Tag the existing examples per the mapping in design.md (metadata only) in `spec/domain/guest_name_spec.rb`, `greeting_spec.rb`, `greet_guest_spec.rb`, `spec/ports/clock_spec.rb`, `greeting_presenter_spec.rb`, `spec/benchmarks/greeting_service_bench.rb`; tag the new specs per the delta spec
- [ ] 1.7 Commit as `test(adopt-live-docs): ...` with the failing output

## 2. Implementation

- [ ] 2.1 `spec/support/slug.rb` (`RepoTrace::Slug`)
- [ ] 2.2 `spec/support/trace_check.rb` (`RepoTrace::Check`)
- [ ] 2.3 `spec/support/repo_trace_formatter.rb`; add `--require support/repo_trace_formatter` to `.rspec`; validate slug, location, sha and run_id patterns before writing, and run `git rev-parse HEAD` with an argument array, no shell (S3)
- [ ] 2.4 `bin/merge-repo-trace` (stdlib only, executable bit, frozen string literal); `JSON.parse` only, allowlisted keys, statuses, `source` and value patterns, no output on error (S4); confirm the gemspec does not package `bin/`
- [ ] 2.5 Update `.github/workflows/ci.yml`: schedule, formatter and artifact upload in `functional` and `performance`, `trace` job (`persist-credentials: false`, same-run downloads by name, no `run-id`/`merge-multiple`), `notify-docs` job (token via `env: GH_TOKEN`, constant payload, no `${{` in `run:`), explicit `publish` condition (S5-S7)
- [ ] 2.6 Update `.talismanrc` checksums for edited tracked files
- [ ] 2.7 In `ci.yml` add top-level `permissions: {contents: read}` (keep `publish` with `id-token: write`, `contents: read`; `notify-docs` with `{}`) and pass `permission-contents: write` to `actions/create-github-app-token@v3` (S1, S2)

## 3. Verify and docs

- [ ] 3.1 `bundle exec rspec`, then `REPO_TRACE_PATH=tmp/repo-trace-functional.json bundle exec rspec --format RepoTraceFormatter` and the same for `spec/benchmarks/` to `tmp/repo-trace-performance.json`; run `bin/merge-repo-trace` on them and inspect the merged file (every requirement present, no descriptions)
- [ ] 3.2 `bundle exec rubocop` (including `bin/merge-repo-trace`)
- [ ] 3.3 Tag-only check on modified spec files (must print nothing):
  ```
  for f in $(git diff main --name-only --diff-filter=M -- spec ':!spec/support' ':!spec/fixtures'); do
    ruby -e 'o = `git show main:#{ARGV[0]}`; n = File.read(ARGV[0]).gsub(/,\s*(requirement|scenario):\s*\x27[^\x27]*\x27/, ""); abort "#{ARGV[0]}: changed beyond tags" unless o.gsub(/\s+/, "") == n.gsub(/\s+/, "")' "$f"
  done
  ```
- [ ] 3.4 Informational: run the requested pipeline `git diff main -- spec ':!spec/support' ':!spec/trace_check_spec.rb' ':!spec/**/slug*_spec.rb' ':!spec/**/repo_trace*_spec.rb' | grep '^[-+]' | grep -v '^[-+][-+]' | grep -v 'requirement:' | grep -v 'scenario:'`. It lists only the replaced original lines and the new files named in design.md (`spec/ci_workflow_spec.rb`, `spec/fixtures/**`); anything else is a defect
- [ ] 3.5 `openspec validate adopt-live-docs --strict`, then after archive `openspec validate --all --strict`
- [ ] 3.6 Maintainer confirms the greeterhq-dispatch app grants only contents write on greeter-docs, and that the greeter-docs consumer change allowlists `client_payload[repo]` and validates the trace schema (S10). Also confirms before merge: `vars.DISPATCH_APP_CLIENT_ID`, `secrets.DISPATCH_APP_PRIVATE_KEY`, `greeterhq-dispatch` installed on greeter-docs (no fallback is added)
- [ ] 3.7 README note on the `repo-trace` artifact; no CHANGELOG entry (`lib/` unchanged)
