# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

# Runs fixture example files from spec/fixtures/repo_trace in a separate rspec
# process with only the formatter loaded (--options /dev/null skips .rspec and
# spec_helper), then reads the trace file it wrote.
RSpec.describe 'RepoTraceFormatter' do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:fixture_dir) { 'spec/fixtures/repo_trace' }
  let(:tmpdir) { Dir.mktmpdir('repo-trace') }
  let(:trace_path) { File.join(tmpdir, 'repo-trace.json') }
  let(:sha) { '0123456789abcdef0123456789abcdef01234567' }
  let(:ci_env) { { 'GITHUB_SHA' => sha, 'GITHUB_RUN_ID' => '987654321' } }

  after { FileUtils.remove_entry(tmpdir) }

  def run_fixture(name, env = ci_env)
    command = [RbConfig.ruby, Gem.bin_path('rspec-core', 'rspec'),
               '--options', File::NULL,
               '--require', File.join(root, 'spec/support/repo_trace_formatter.rb'),
               '--format', 'RepoTraceFormatter',
               "#{fixture_dir}/#{name}"]
    output, _status = Open3.capture2e(env.merge('REPO_TRACE_PATH' => trace_path), *command, chdir: root)
    output
  end

  def trace_for(name, env = ci_env)
    output = run_fixture(name, env)
    expect(File).to exist(trace_path), "formatter wrote no trace. rspec output:\n#{output}"
    JSON.parse(File.read(trace_path))
  end

  def result(trace, scenario)
    trace.fetch('results').find { |entry| entry['scenario'] == scenario }
  end

  def line_of(name, text)
    File.readlines(File.join(root, fixture_dir, name)).index { |line| line.include?(text) } + 1
  end

  it 'writes the v1 document with passed and failed results',
     :aggregate_failures,
     requirement: 'repo-trace-contains-only-slugs-statuses-locations-and-run-metadata',
     scenario: 'formatter-writes-the-v1-document' do
    trace = trace_for('statuses_example.rb')
    location = "#{fixture_dir}/statuses_example.rb:#{line_of('statuses_example.rb', "'passes'")}"
    expect(trace).to include('schema' => 'greeterhq.repo-trace.v1', 'repo' => 'greeter-core',
                             'sha' => sha, 'run_id' => '987654321')
    expect(trace['recorded_at']).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z\z/)
    expect(result(trace, 'demo-passes')).to eq(
      'requirement' => 'demo-requirement', 'scenario' => 'demo-passes', 'status' => 'passed',
      'source' => 'rspec', 'location' => location
    )
    expect(result(trace, 'demo-fails')).to include('status' => 'failed', 'source' => 'rspec')
  end

  it 'leaves untagged examples out of the results',
     requirement: 'repo-trace-contains-only-slugs-statuses-locations-and-run-metadata',
     scenario: 'formatter-writes-the-v1-document' do
    scenarios = trace_for('statuses_example.rb')['results'].map { |entry| entry['scenario'] }
    expect(scenarios).to contain_exactly('demo-passes', 'demo-fails', 'demo-skipped', 'demo-pending')
  end

  it 'falls back to git rev-parse HEAD and a null run_id outside GitHub Actions',
     :aggregate_failures,
     requirement: 'repo-trace-contains-only-slugs-statuses-locations-and-run-metadata',
     scenario: 'formatter-writes-the-v1-document' do
    head = IO.popen(['git', '-C', root, 'rev-parse', 'HEAD'], &:read).strip
    trace = trace_for('statuses_example.rb', { 'GITHUB_SHA' => nil, 'GITHUB_RUN_ID' => nil })
    expect(trace['sha']).to eq(head)
    expect(trace).to include('run_id' => nil)
  end

  it 'reports an example marked skip as skipped',
     requirement: 'repo-trace-contains-only-slugs-statuses-locations-and-run-metadata',
     scenario: 'formatter-tells-skipped-from-pending' do
    expect(result(trace_for('statuses_example.rb'), 'demo-skipped')).to include('status' => 'skipped')
  end

  it 'reports an example marked pending as pending',
     requirement: 'repo-trace-contains-only-slugs-statuses-locations-and-run-metadata',
     scenario: 'formatter-tells-skipped-from-pending' do
    expect(result(trace_for('statuses_example.rb'), 'demo-pending')).to include('status' => 'pending')
  end

  it 'collapses a shared example included twice to one result with the worst status',
     requirement: 'repo-trace-contains-only-slugs-statuses-locations-and-run-metadata',
     scenario: 'formatter-writes-the-v1-document' do
    results = trace_for('shared_example.rb')['results'].select { |entry| entry['scenario'] == 'demo-shared' }
    expect(results).to contain_exactly(a_hash_including('status' => 'failed'))
  end

  it 'gives a shared example the tags of the context that wraps it',
     requirement: 'repo-trace-contains-only-slugs-statuses-locations-and-run-metadata',
     scenario: 'formatter-writes-the-v1-document' do
    results = trace_for('wrapped_shared_example.rb')['results']
    expect(results).to contain_exactly(
      a_hash_including('requirement' => 'demo-requirement', 'scenario' => 'demo-wrapped-first', 'status' => 'passed'),
      a_hash_including('requirement' => 'demo-requirement', 'scenario' => 'demo-wrapped-second', 'status' => 'passed')
    )
  end

  it 'refuses a requirement tag that is not a slug and writes no file',
     :aggregate_failures,
     requirement: 'repo-trace-contains-only-slugs-statuses-locations-and-run-metadata',
     scenario: 'formatter-refuses-malformed-values' do
    output = run_fixture('malformed_tag_example.rb')
    expect(output).to match(/invalid requirement/i)
    expect(File).not_to exist(trace_path)
  end

  it 'refuses a GITHUB_SHA that is not 40 hex characters and writes no file',
     :aggregate_failures,
     requirement: 'repo-trace-contains-only-slugs-statuses-locations-and-run-metadata',
     scenario: 'formatter-refuses-malformed-values' do
    output = run_fixture('statuses_example.rb', ci_env.merge('GITHUB_SHA' => 'main; rm -rf /'))
    expect(output).to match(/invalid sha/i)
    expect(File).not_to exist(trace_path)
  end

  it 'refuses a GITHUB_RUN_ID that is not digits and writes no file',
     :aggregate_failures,
     requirement: 'repo-trace-contains-only-slugs-statuses-locations-and-run-metadata',
     scenario: 'formatter-refuses-malformed-values' do
    output = run_fixture('statuses_example.rb', ci_env.merge('GITHUB_RUN_ID' => '12<script>'))
    expect(output).to match(/invalid run_id/i)
    expect(File).not_to exist(trace_path)
  end

  it 'never writes descriptions or failure messages',
     :aggregate_failures,
     requirement: 'repo-trace-contains-only-slugs-statuses-locations-and-run-metadata',
     scenario: 'formatter-omits-descriptions' do
    trace = trace_for('privacy_example.rb')
    expect(File.read(trace_path)).not_to include('Alice Smith')
    expect(trace.keys).to contain_exactly('schema', 'repo', 'sha', 'recorded_at', 'run_id', 'results')
    expect(trace['results']).not_to be_empty
    expect(trace['results']).to all(satisfy { |entry|
      entry.keys.sort == %w[location requirement scenario source status]
    })
  end
end
