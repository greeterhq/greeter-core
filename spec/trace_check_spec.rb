# frozen_string_literal: true

# RepoTrace::Check.call(spec_glob:, example_glob:, exclude_glob: nil) returns a
# list of problem strings. Paths are relative to the repo root (rspec's cwd).
RSpec.describe 'RepoTrace::Check' do
  let(:fixture_dir) { 'spec/fixtures/trace_check' }
  let(:fixture_spec) { "#{fixture_dir}/specs/alpha/spec.md" }

  def problems_for(example_file)
    RepoTrace::Check.call(spec_glob: "#{fixture_dir}/specs/**/spec.md",
                          example_glob: "#{fixture_dir}/examples/#{example_file}")
  end

  it 'names a requirement that has no tagged example, with its spec file',
     requirement: 'every-requirement-has-a-tagged-example',
     scenario: 'requirement-with-no-tagged-example-fails-and-is-named' do
    expect(problems_for('covered.rb')).to contain_exactly(a_string_including('beta-uncovered', fixture_spec))
  end

  it 'names an unknown requirement slug, with the example file and line',
     requirement: 'tagged-examples-must-match-a-requirement-and-scenario',
     scenario: 'unknown-requirement-slug-fails-and-is-named' do
    expect(problems_for('unknown.rb'))
      .to include(a_string_including('no-such-requirement', "#{fixture_dir}/examples/unknown.rb:5"))
  end

  it 'names a scenario slug used under the wrong requirement, and accepts one equal to its requirement',
     :aggregate_failures,
     requirement: 'tagged-examples-must-match-a-requirement-and-scenario',
     scenario: 'scenario-slug-is-matched-only-within-its-requirement' do
    problems = problems_for('{covered,wrong_scenario}.rb')
    expect(problems).to include(
      a_string_including('beta-works', 'alpha-covered', "#{fixture_dir}/examples/wrong_scenario.rb:5")
    )
    expect(problems).not_to include(a_string_including('gamma-same-text'))
  end

  describe 'with in-flight change deltas' do
    # A broad glob on purpose: it also matches changes/archive/**, which the
    # check itself must skip.
    def delta_problems
      RepoTrace::Check.call(spec_glob: "#{fixture_dir}/specs/**/spec.md",
                            change_glob: "#{fixture_dir}/changes/**/specs/**/spec.md",
                            example_glob: "#{fixture_dir}/examples/{covered,in_flight}.rb")
    end

    it 'knows ADDED and MODIFIED headings from a change that is not archived',
       :aggregate_failures,
       requirement: 'tagged-examples-must-match-a-requirement-and-scenario',
       scenario: 'requirements-in-in-flight-changes-are-known' do
      expect(delta_problems).not_to include(a_string_including('delta-added'))
      expect(delta_problems).not_to include(a_string_including('alpha-also-works'))
      expect(delta_problems).to include(a_string_including('beta-uncovered'))
    end

    it 'treats a slug found only in an archived change as unknown',
       requirement: 'tagged-examples-must-match-a-requirement-and-scenario',
       scenario: 'requirements-in-in-flight-changes-are-known' do
      expect(delta_problems)
        .to include(a_string_including('archived-only', "#{fixture_dir}/examples/in_flight.rb:7"))
    end

    it 'ignores headings in REMOVED and RENAMED sections',
       :aggregate_failures,
       requirement: 'tagged-examples-must-match-a-requirement-and-scenario',
       scenario: 'requirements-in-in-flight-changes-are-known' do
      expect(delta_problems).to include(a_string_including('removed-thing', "#{fixture_dir}/examples/in_flight.rb:8"))
      expect(delta_problems).to include(a_string_including('new-name', "#{fixture_dir}/examples/in_flight.rb:9"))
    end
  end

  it 'finds no problems in this repository',
     requirement: 'every-requirement-has-a-tagged-example',
     scenario: 'requirement-with-no-tagged-example-fails-and-is-named' do
    problems = RepoTrace::Check.call(spec_glob: 'openspec/specs/**/spec.md',
                                     change_glob: 'openspec/changes/**/specs/**/spec.md',
                                     example_glob: 'spec/**/*.rb',
                                     exclude_glob: 'spec/fixtures/**/*')
    expect(problems).to be_empty, "Trace-check problems:\n#{problems.join("\n")}"
  end
end
