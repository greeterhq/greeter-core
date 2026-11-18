# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'rspec/core'
require 'time'

# Writes a greeterhq.repo-trace.v1 file for greeter-docs: one result per
# example tagged with both requirement: and scenario: metadata (tags on an
# enclosing context count). It records only slugs, statuses, locations and run
# metadata. It never reads descriptions, failure messages or exceptions,
# because those can contain guest names.
#
# Select it with `--format RepoTraceFormatter`. Output goes to
# ENV['REPO_TRACE_PATH'] (default tmp/repo-trace.json), relative to the root.
class RepoTraceFormatter
  class InvalidTrace < StandardError; end

  RSpec::Core::Formatters.register self, :example_passed, :example_failed, :example_pending, :close

  SCHEMA = 'greeterhq.repo-trace.v1'
  REPO = 'greeter-core'
  DEFAULT_PATH = 'tmp/repo-trace.json'
  SLUG = /\A[a-z0-9]+(-[a-z0-9]+)*\z/
  LOCATION = %r{\Aspec/[\w./-]+\.rb:\d+\z}
  SHA = /\A[0-9a-f]{40}\z/
  RUN_ID = /\A\d+\z/
  # Worst first: when results collapse onto one location, the worst status wins.
  STATUS_RANK = %w[failed pending skipped passed].freeze

  def initialize(_output, env: ENV, clock: Time, root: Dir.pwd)
    @env = env
    @clock = clock
    @root = root
    @results = []
  end

  def example_passed(notification)
    record(notification.example, 'passed')
  end

  def example_failed(notification)
    record(notification.example, 'failed')
  end

  # RSpec reports both `skip` and `pending` here; :skip metadata marks a skip.
  def example_pending(notification)
    example = notification.example
    record(example, example.metadata[:skip] ? 'skipped' : 'pending')
  end

  def close(_notification)
    document = build_document
    path = File.expand_path(@env.fetch('REPO_TRACE_PATH', DEFAULT_PATH), @root)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#{JSON.pretty_generate(document)}\n")
  end

  private

  def record(example, status)
    requirement = example.metadata[:requirement]
    scenario = example.metadata[:scenario]
    return if requirement.nil? || scenario.nil?

    @results << { 'requirement' => requirement, 'scenario' => scenario, 'status' => status,
                  'source' => 'rspec', 'location' => relative_location(example.location) }
  end

  def relative_location(location)
    file, line = location.to_s.split(':', 2)
    relative = File.expand_path(file, @root).delete_prefix("#{File.expand_path(@root)}/")
    "#{relative}:#{line}"
  end

  def build_document
    results = collapse(@results).each { |result| validate_result(result) }
    { 'schema' => SCHEMA, 'repo' => REPO, 'sha' => sha, 'recorded_at' => @clock.now.utc.iso8601,
      'run_id' => run_id, 'results' => results }
  end

  def collapse(results)
    results.group_by { |result| result.values_at('requirement', 'scenario', 'location') }
           .map { |_, group| group.min_by { |result| STATUS_RANK.index(result['status']) } }
           .sort_by { |result| result.values_at('location', 'requirement', 'scenario') }
  end

  def validate_result(result)
    check(result['location'], LOCATION, 'invalid location (expected spec/...rb:LINE)')
    %w[requirement scenario].each do |field|
      check(result[field], SLUG, "invalid #{field} tag on the example at #{result['location']} " \
                                 '(expected a lowercase slug)')
    end
  end

  def sha
    value = @env['GITHUB_SHA'] || IO.popen(['git', '-C', @root, 'rev-parse', 'HEAD'], err: File::NULL, &:read).strip
    check(value, SHA, 'invalid sha (expected 40 lowercase hex characters)')
  end

  def run_id
    value = @env['GITHUB_RUN_ID']
    value.nil? ? nil : check(value, RUN_ID, 'invalid run_id (expected digits)')
  end

  # Raises without echoing the value, so a bad tag never reaches the logs.
  def check(value, pattern, message)
    raise InvalidTrace, message unless value.is_a?(String) && value.match?(pattern)

    value
  end
end
