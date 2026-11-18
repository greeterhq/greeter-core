# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

# Runs bin/merge-repo-trace OUT IN_A IN_B as a subprocess, the way CI calls it.
RSpec.describe 'bin/merge-repo-trace' do
  let(:script) { File.expand_path('../../bin/merge-repo-trace', __dir__) }
  let(:tmpdir) { Dir.mktmpdir('merge-repo-trace') }
  let(:out_path) { File.join(tmpdir, 'repo-trace.json') }
  let(:functional_path) { File.join(tmpdir, 'functional.json') }
  let(:performance_path) { File.join(tmpdir, 'performance.json') }
  let(:sha) { '0123456789abcdef0123456789abcdef01234567' }

  let(:functional_result) do
    entry('validates-and-normalises-a-guest-name', 'normalises-whitespace-and-casing',
          'spec/domain/guest_name_spec.rb:31')
  end
  let(:performance_result) do
    entry('greeting-construction-stays-within-latency-budget', 'completes-greet-in-under-5-ms-at-p99',
          'spec/benchmarks/greeting_service_bench.rb:13')
  end
  let(:functional) { trace(recorded_at: '2026-11-09T06:17:05Z', results: [functional_result]) }
  let(:performance) { trace(recorded_at: '2026-11-09T06:17:42Z', results: [performance_result]) }

  after { FileUtils.remove_entry(tmpdir) }

  def trace(recorded_at:, results:, **overrides)
    { 'schema' => 'greeterhq.repo-trace.v1', 'repo' => 'greeter-core', 'sha' => sha,
      'recorded_at' => recorded_at, 'run_id' => '987654321', 'results' => results }.merge(overrides)
  end

  def entry(requirement, scenario, location, status: 'passed')
    { 'requirement' => requirement, 'scenario' => scenario, 'status' => status,
      'source' => 'rspec', 'location' => location }
  end

  # Returns a copy of the trace whose single result has +changes+ applied.
  def with_result(trace, changes)
    trace.merge('results' => [trace['results'].first.merge(changes)])
  end

  def merge(first, second)
    File.write(functional_path, JSON.generate(first))
    File.write(performance_path, JSON.generate(second))
    _stdout, stderr, status = Open3.capture3(RbConfig.ruby, script, out_path, functional_path, performance_path)
    [stderr, status]
  end

  def expect_rejected(first, second, *message_parts)
    stderr, status = merge(first, second)
    expect(status).not_to be_success
    expect(stderr).to include(*message_parts)
    expect(File).not_to exist(out_path)
  end

  it 'combines the results of both traces under the shared run metadata',
     :aggregate_failures,
     requirement: 'per-job-traces-merge-into-one-trace',
     scenario: 'merge-combines-both-traces' do
    stderr, status = merge(functional, performance)
    expect(status).to be_success, stderr
    merged = JSON.parse(File.read(out_path))
    expect(merged).to include('schema' => 'greeterhq.repo-trace.v1', 'repo' => 'greeter-core', 'sha' => sha,
                              'run_id' => '987654321', 'recorded_at' => '2026-11-09T06:17:42Z')
    expect(merged['results']).to contain_exactly(functional_result, performance_result)
  end

  it 'keeps the later recorded_at whichever input it comes from',
     requirement: 'per-job-traces-merge-into-one-trace',
     scenario: 'merge-combines-both-traces' do
    merge(performance, functional)
    expect(JSON.parse(File.read(out_path))).to include('recorded_at' => '2026-11-09T06:17:42Z')
  end

  %w[schema repo sha].each do |field|
    it "rejects inputs whose #{field} differs and writes nothing",
       :aggregate_failures,
       requirement: 'per-job-traces-merge-into-one-trace',
       scenario: 'merge-rejects-mismatched-inputs' do
      other = { 'schema' => 'greeterhq.repo-trace.v2', 'repo' => 'greeter-cli', 'sha' => 'f' * 40 }.fetch(field)
      expect_rejected(functional, performance.merge(field => other), "#{field} differs")
    end
  end

  [%w[1 2], [nil, '2']].each do |first_id, second_id|
    it "rejects run_id #{first_id.inspect} against #{second_id.inspect} and writes nothing",
       :aggregate_failures,
       requirement: 'per-job-traces-merge-into-one-trace',
       scenario: 'merge-rejects-differing-run-ids' do
      expect_rejected(functional.merge('run_id' => first_id), performance.merge('run_id' => second_id),
                      'run_id differs')
    end
  end

  it 'rejects an input with an unknown top-level key, naming the file and key',
     :aggregate_failures,
     requirement: 'per-job-traces-merge-into-one-trace',
     scenario: 'merge-rejects-inputs-outside-the-v1-shape' do
    expect_rejected(functional.merge('notes' => 'hi'), performance, functional_path, 'notes')
  end

  {
    'a result with an extra key' => ['description', 'Alice Smith'],
    'a status outside the v1 set' => %w[status broken],
    'a source other than rspec' => %w[source cucumber],
    'a requirement that is not a slug' => ['requirement', 'Alice Smith'],
    'a scenario that is not a slug' => %w[scenario ../etc],
    'a location outside spec/' => ['location', '/etc/passwd:1']
  }.each do |label, (field, value)|
    it "rejects an input with #{label}, naming the file and field",
       :aggregate_failures,
       requirement: 'per-job-traces-merge-into-one-trace',
       scenario: 'merge-rejects-inputs-outside-the-v1-shape' do
      expect_rejected(with_result(functional, field => value), performance, functional_path, field)
    end
  end

  it 'rejects a result present in both inputs, naming it, and writes nothing',
     :aggregate_failures,
     requirement: 'per-job-traces-merge-into-one-trace',
     scenario: 'merge-rejects-a-duplicated-result' do
    duplicated = performance.merge('results' => [performance_result, functional_result])
    expect_rejected(functional, duplicated, functional_result['requirement'], functional_result['location'])
  end
end
