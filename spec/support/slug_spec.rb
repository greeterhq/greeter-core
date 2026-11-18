# frozen_string_literal: true

# Slug rule shared by every greeterHQ repo: lowercase, replace each run of
# characters other than a-z and 0-9 with one "-", trim "-" from both ends.
# No camel-case splitting. Expected slugs are written by hand, never computed.
RSpec.describe 'RepoTrace::Slug' do
  let(:shared_table) do
    {
      'Greets a named guest' => 'greets-a-named-guest',
      'Surfaces control/escape characters as an error' => 'surfaces-control-escape-characters-as-an-error',
      'Greet a guest and return a running count' => 'greet-a-guest-and-return-a-running-count',
      'Clock port declares an unimplemented #now' => 'clock-port-declares-an-unimplemented-now',
      'GreetingPresenter port declares an unimplemented #present' =>
        'greetingpresenter-port-declares-an-unimplemented-present',
      'Base Clock#now raises NotImplementedError' => 'base-clock-now-raises-notimplementederror',
      'Rejects a name longer than 64 characters' => 'rejects-a-name-longer-than-64-characters',
      'Completes #greet in under 5 ms at p99' => 'completes-greet-in-under-5-ms-at-p99',
      'Equal names agree across ==, eql?, hash, and uniq' => 'equal-names-agree-across-eql-hash-and-uniq',
      '  --Leading and trailing!!  ' => 'leading-and-trailing'
    }
  end

  # Every "### Requirement:" and "#### Scenario:" heading in this repo's specs,
  # including the live-docs-traceability capability added by adopt-live-docs.
  let(:repo_headings) do
    {
      'Validates and normalises a guest name' => 'validates-and-normalises-a-guest-name',
      'Normalises whitespace and casing' => 'normalises-whitespace-and-casing',
      'Rejects an empty or whitespace-only name' => 'rejects-an-empty-or-whitespace-only-name',
      'Rejects names containing control or escape characters' =>
        'rejects-names-containing-control-or-escape-characters',
      'Rejects a name containing a control or escape character' =>
        'rejects-a-name-containing-a-control-or-escape-character',
      'Greeting is an immutable value object' => 'greeting-is-an-immutable-value-object',
      'Greeting holds its fields and is frozen' => 'greeting-holds-its-fields-and-is-frozen',
      'GreetingService composes a Greeting from an injected clock' =>
        'greetingservice-composes-a-greeting-from-an-injected-clock',
      'Returns a Greeting for a valid name' => 'returns-a-greeting-for-a-valid-name',
      'Propagates InvalidGuestName for bad input' => 'propagates-invalidguestname-for-bad-input',
      'Greeting construction stays within latency budget' => 'greeting-construction-stays-within-latency-budget',
      'GuestName is a value object with a consistent equality contract' =>
        'guestname-is-a-value-object-with-a-consistent-equality-contract',
      'Base GreetingPresenter#present raises NotImplementedError' =>
        'base-greetingpresenter-present-raises-notimplementederror',
      'Every requirement has a tagged example' => 'every-requirement-has-a-tagged-example',
      'Slug rule turns headings into slugs' => 'slug-rule-turns-headings-into-slugs',
      'Requirement with no tagged example fails and is named' =>
        'requirement-with-no-tagged-example-fails-and-is-named',
      'Tagged examples must match a requirement and scenario' =>
        'tagged-examples-must-match-a-requirement-and-scenario',
      'Unknown requirement slug fails and is named' => 'unknown-requirement-slug-fails-and-is-named',
      'Scenario slug is matched only within its requirement' =>
        'scenario-slug-is-matched-only-within-its-requirement',
      'Repo trace contains only slugs, statuses, locations and run metadata' =>
        'repo-trace-contains-only-slugs-statuses-locations-and-run-metadata',
      'Formatter writes the v1 document' => 'formatter-writes-the-v1-document',
      'Formatter tells skipped from pending' => 'formatter-tells-skipped-from-pending',
      'Formatter refuses malformed values' => 'formatter-refuses-malformed-values',
      'Formatter omits descriptions' => 'formatter-omits-descriptions',
      'Per-job traces merge into one trace' => 'per-job-traces-merge-into-one-trace',
      'Merge combines both traces' => 'merge-combines-both-traces',
      'Merge rejects mismatched inputs' => 'merge-rejects-mismatched-inputs',
      'Merge rejects differing run ids' => 'merge-rejects-differing-run-ids',
      'Merge rejects inputs outside the v1 shape' => 'merge-rejects-inputs-outside-the-v1-shape',
      'Merge rejects a duplicated result' => 'merge-rejects-a-duplicated-result',
      'CI publishes the trace on main and weekly' => 'ci-publishes-the-trace-on-main-and-weekly',
      'Functional and performance upload their own traces' => 'functional-and-performance-upload-their-own-traces',
      'Trace job merges and uploads on main and schedule' => 'trace-job-merges-and-uploads-on-main-and-schedule',
      'Notify-docs dispatches docs-refresh' => 'notify-docs-dispatches-docs-refresh',
      'Workflow credentials are least-privilege' => 'workflow-credentials-are-least-privilege',
      'Only tag pushes publish' => 'only-tag-pushes-publish'
    }
  end

  let(:spec_headings) do
    Dir[File.expand_path('../../openspec/specs/**/spec.md', __dir__)].flat_map do |path|
      File.read(path).scan(/^####?\s+(?:Requirement|Scenario):\s*(.+?)\s*$/).flatten
    end
  end

  it 'turns every heading in the slug table and the repo into its slug',
     :aggregate_failures,
     requirement: 'every-requirement-has-a-tagged-example',
     scenario: 'slug-rule-turns-headings-into-slugs' do
    shared_table.merge(repo_headings).each do |heading, slug|
      expect(RepoTrace::Slug.call(heading)).to eq(slug), "#{heading.inspect} should slug to #{slug}"
    end
  end

  it 'has a hand-written slug for every heading in openspec/specs' do
    expect(spec_headings - shared_table.keys - repo_headings.keys).to be_empty
  end
end
