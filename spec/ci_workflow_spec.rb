# frozen_string_literal: true

require 'open3'
require 'shellwords'
require 'tmpdir'
require 'yaml'

# Structural checks on .github/workflows/ci.yml for the live-docs pipeline.
RSpec.describe 'CI workflow' do
  let(:workflow) { YAML.safe_load_file(File.expand_path('../.github/workflows/ci.yml', __dir__)) }
  let(:gate) { "github.event_name == 'schedule' || (github.event_name == 'push' && github.ref == 'refs/heads/main')" }

  def job(name)
    expect(workflow.fetch('jobs')).to include(name)
    workflow['jobs'].fetch(name, {})
  end

  def steps(name)
    job(name).fetch('steps', [])
  end

  def step_using(name, action)
    steps(name).select { |step| step['uses'].to_s.start_with?(action) }
  end

  def upload(name, artifact)
    step_using(name, 'actions/upload-artifact').find { |step| step.dig('with', 'name') == artifact }
  end

  def condition(value)
    value.to_s.sub(/\A\$\{\{\s*/, '').sub(/\s*\}\}\z/, '').gsub(/\s+/, ' ').strip
  end

  def runs_formatter_with_path?(name, path)
    steps(name).any? do |step|
      run = step['run'].to_s
      run.include?('RepoTraceFormatter') &&
        (run.include?("REPO_TRACE_PATH=#{path}") || step.dig('env', 'REPO_TRACE_PATH') == path)
    end
  end

  describe 'per-job traces' do
    it 'runs the formatter in functional and uploads repo-trace-functional for one day',
       :aggregate_failures,
       requirement: 'ci-publishes-the-trace-on-main-and-weekly',
       scenario: 'functional-and-performance-upload-their-own-traces' do
      expect(runs_formatter_with_path?('functional', 'tmp/repo-trace-functional.json')).to be(true)
      expect(upload('functional', 'repo-trace-functional')&.fetch('with'))
        .to include('path' => 'tmp/repo-trace-functional.json', 'retention-days' => 1)
      expect(steps('functional').map { |step| step['run'].to_s }.join).not_to include('spec/benchmarks')
    end

    it 'runs the benchmark with the formatter only in performance and uploads repo-trace-performance',
       :aggregate_failures,
       requirement: 'ci-publishes-the-trace-on-main-and-weekly',
       scenario: 'functional-and-performance-upload-their-own-traces' do
      expect(runs_formatter_with_path?('performance', 'tmp/repo-trace-performance.json')).to be(true)
      expect(steps('performance').map { |step| step['run'].to_s }.join).to include('spec/benchmarks')
      expect(upload('performance', 'repo-trace-performance')&.fetch('with'))
        .to include('path' => 'tmp/repo-trace-performance.json', 'retention-days' => 1)
    end
  end

  # Runs the performance job's own rspec command from ci.yml with --dry-run, so
  # a command that selects no files (as `rspec spec/benchmarks/` does with the
  # default *_spec.rb pattern) fails here instead of passing silently in CI.
  # Leading VAR=value words are dropped; REPO_TRACE_PATH points at a temp file.
  describe 'performance command' do
    def performance_command
      line = steps('performance').flat_map { |step| step['run'].to_s.lines }
                                 .find { |text| text.include?('rspec') }
      Shellwords.split(line.to_s).drop_while { |word| word.match?(/\A[A-Z_]+=/) }
    end

    it 'selects at least one benchmark example',
       :aggregate_failures,
       requirement: 'ci-publishes-the-trace-on-main-and-weekly',
       scenario: 'functional-and-performance-upload-their-own-traces' do
      command = performance_command
      expect(command).to include('rspec')
      output = Dir.mktmpdir('ci-dry-run') do |dir|
        Open3.capture2e({ 'REPO_TRACE_PATH' => File.join(dir, 'trace.json') }, *command, '--dry-run',
                        chdir: File.expand_path('..', __dir__)).first
      end
      expect(output).not_to include('No examples found')
      expect(output).to match(/^[1-9]\d* examples?, /)
    end
  end

  describe 'trace job' do
    it 'merges both traces and uploads repo-trace for 90 days on main and schedule',
       :aggregate_failures,
       requirement: 'ci-publishes-the-trace-on-main-and-weekly',
       scenario: 'trace-job-merges-and-uploads-on-main-and-schedule' do
      expect(workflow.dig('on', 'schedule')).to include('cron' => '17 6 * * 1')
      expect(Array(job('trace')['needs'])).to contain_exactly('functional', 'performance')
      expect(job('trace')['permissions']).to eq('contents' => 'read')
      expect(condition(job('trace')['if'])).to eq(gate)
      expect(step_using('trace', 'actions/download-artifact').map { |step| step.dig('with', 'name') })
        .to contain_exactly('repo-trace-functional', 'repo-trace-performance')
      expect(steps('trace').map { |step| step['run'].to_s }.join).to include('bin/merge-repo-trace')
      expect(upload('trace', 'repo-trace')&.fetch('with'))
        .to include('path' => 'tmp/repo-trace.json', 'retention-days' => 90)
    end
  end

  describe 'notify-docs job' do
    it 'sends docs-refresh to greeter-docs with an app token after the trace job',
       :aggregate_failures,
       requirement: 'ci-publishes-the-trace-on-main-and-weekly',
       scenario: 'notify-docs-dispatches-docs-refresh' do
      expect(Array(job('notify-docs')['needs'])).to eq(['trace'])
      expect(job('notify-docs')['permissions']).to eq({})
      expect(condition(job('notify-docs')['if'])).to eq(gate)
      expect(step_using('notify-docs', 'actions/create-github-app-token@v3').first&.fetch('with')).to include(
        'client-id' => '${{ vars.DISPATCH_APP_CLIENT_ID }}',
        'private-key' => '${{ secrets.DISPATCH_APP_PRIVATE_KEY }}',
        'owner' => 'greeterhq', 'repositories' => 'greeter-docs'
      )
      expect(steps('notify-docs').map { |step| step['run'].to_s }.join).to include(
        'repos/greeterhq/greeter-docs/dispatches', 'event_type=docs-refresh', 'client_payload[repo]=greeter-core'
      )
    end
  end

  describe 'credentials' do
    it 'grants least privilege and keeps expressions out of run steps',
       :aggregate_failures,
       requirement: 'ci-publishes-the-trace-on-main-and-weekly',
       scenario: 'workflow-credentials-are-least-privilege' do
      expect(workflow['permissions']).to eq('contents' => 'read')
      token_step = step_using('notify-docs', 'actions/create-github-app-token@v3').first
      expect(token_step&.fetch('with')).to include('permission-contents' => 'write')
      dispatch = steps('notify-docs').find { |step| step['run'].to_s.include?('docs-refresh') }
      token_ref = /\A\$\{\{\s*steps\.#{token_step&.fetch('id', nil)}\.outputs\.token\s*\}\}\z/
      expect(dispatch&.dig('env', 'GH_TOKEN')).to match(token_ref)
      run_scripts = (steps('trace') + steps('notify-docs')).map { |step| step['run'].to_s }
      expect(run_scripts).to all(satisfy { |run| !run.include?('${{') })
      expect(step_using('trace', 'actions/checkout').map { |step| step.dig('with', 'persist-credentials') })
        .to eq([false])
      expect(step_using('trace', 'actions/download-artifact').map { |step| step['with'].keys })
        .to all(satisfy { |keys| !keys.intersect?(%w[run-id merge-multiple github-token]) })
    end
  end

  describe 'publish job' do
    it 'publishes only on v* tag pushes, and the trace gate excludes pull requests',
       :aggregate_failures,
       requirement: 'ci-publishes-the-trace-on-main-and-weekly',
       scenario: 'only-tag-pushes-publish' do
      expect(condition(job('publish')['if']))
        .to eq("github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')")
      expect(gate).not_to include('pull_request')
      expect(workflow['on']).to include('pull_request', 'push', 'schedule')
      expect(%w[functional performance].map { |name| job(name)['if'] }).to eq([nil, nil])
    end
  end
end
