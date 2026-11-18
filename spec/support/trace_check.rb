# frozen_string_literal: true

require_relative 'slug'

module RepoTrace
  # Cross-checks OpenSpec requirement headings against RSpec tags.
  #
  # Headings come from main specs (spec_glob) and, optionally, from the ADDED
  # and MODIFIED sections of change deltas (change_glob) that are not under
  # changes/archive/. Tags are read as text from example files (example_glob
  # minus exclude_glob), so files outside the default rspec run (benchmarks)
  # count too. Returns problem strings; an empty list means the trace is whole.
  class Check
    TAG = /requirement:\s*'([^']+)',\s*scenario:\s*'([^']+)'/
    REQUIREMENT = /\A###\s+Requirement:\s*(.+?)\s*\z/
    SCENARIO = /\A####\s+Scenario:\s*(.+?)\s*\z/
    SECTION = /\A##\s+(\w+)\s+Requirements\s*\z/
    COUNTED_SECTIONS = %w[ADDED MODIFIED].freeze
    ARCHIVE = %r{(\A|/)changes/archive/}

    Requirement = Struct.new(:file, :scenarios)
    Tag = Struct.new(:requirement, :scenario, :location)

    def self.call(spec_glob:, example_glob:, change_glob: nil, exclude_glob: nil)
      new(spec_glob:, example_glob:, change_glob:, exclude_glob:).problems
    end

    def initialize(spec_glob:, example_glob:, change_glob:, exclude_glob:)
      @requirements = {}
      Dir[spec_glob].each { |path| read_headings(path, delta: false) }
      Dir[change_glob.to_s].grep_v(ARCHIVE).each { |path| read_headings(path, delta: true) }
      @tags = example_files(example_glob, exclude_glob).flat_map { |path| read_tags(path) }
    end

    def problems
      uncovered + unknown_requirements + unknown_scenarios
    end

    private

    def uncovered
      tagged = @tags.to_set(&:requirement)
      @requirements.except(*tagged).map do |slug, requirement|
        %(requirement "#{slug}" (#{requirement.file}) has no tagged example)
      end
    end

    def unknown_requirements
      @tags.reject { |tag| @requirements.key?(tag.requirement) }.map do |tag|
        %(example tagged requirement "#{tag.requirement}" (#{tag.location}) matches no requirement heading)
      end
    end

    def unknown_scenarios
      @tags.select { |tag| scenario_mismatch?(tag) }.map do |tag|
        %(example scenario "#{tag.scenario}" (#{tag.location}) is not a scenario of requirement "#{tag.requirement}")
      end
    end

    def scenario_mismatch?(tag)
      requirement = @requirements[tag.requirement]
      requirement && !requirement.scenarios.include?(tag.scenario)
    end

    def read_headings(path, delta:)
      counted = !delta
      current = nil
      File.foreach(path, chomp: true) do |line|
        if (section = line[SECTION, 1]) && delta
          counted = COUNTED_SECTIONS.include?(section)
          current = nil
        elsif counted
          current = heading(path, line, current)
        end
      end
    end

    def heading(path, line, current)
      if (text = line[REQUIREMENT, 1])
        slug = Slug.call(text)
        @requirements[slug] ||= Requirement.new(path, Set.new)
        slug
      elsif (text = line[SCENARIO, 1]) && current
        @requirements[current].scenarios << Slug.call(text)
        current
      else
        current
      end
    end

    def example_files(example_glob, exclude_glob)
      excluded = exclude_glob ? Dir[exclude_glob] : []
      (Dir[example_glob] - excluded).sort
    end

    def read_tags(path)
      text = File.read(path)
      text.to_enum(:scan, TAG).map do
        match = Regexp.last_match
        line = text[0...match.begin(0)].count("\n") + 1
        Tag.new(match[1], match[2], "#{path}:#{line}")
      end
    end
  end
end
