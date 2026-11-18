# frozen_string_literal: true

module RepoTrace
  # Checks that an existing spec file changed only by gaining traceability
  # tags (task 3.3 of adopt-live-docs). Both versions are normalised the same
  # way and then compared:
  #   1. context wrappers carrying requirement:/scenario: tags (see WRAPPER)
  #      are removed with the `end` at the same indentation;
  #   2. requirement:/scenario: tag pairs (with their leading comma) are removed;
  #   3. all whitespace is removed;
  #   4. in spec/spec_helper.rb only, the spec/support loader block is removed.
  # Known limit: step 3 also removes whitespace inside string literals.
  module TagOnlyDiff
    module_function

    SPEC_HELPER = 'spec/spec_helper.rb'
    WRAPPER = /^([ \t]*)context\s+'[^']*',\s*requirement:\s*'[^']*',\s*scenario:\s*'[^']*'\s+do[ \t]*\n/
    TAG_PAIR = /,\s*(?:requirement|scenario):\s*'[^']*'/
    LOADER = <<~RUBY.gsub(/\s+/, '')
      # Spec-side helpers (slug rule, trace-check, repo-trace formatter). Spec files
      # under spec/support are loaded by rspec itself, not here.
      Dir[File.join(__dir__, 'support', '**', '*.rb')].each do |path|
        require path unless path.end_with?('_spec.rb')
      end
    RUBY

    def call(path:, before:, after:)
      return [] if normalise(path, before) == normalise(path, after)

      ["#{path}: changed beyond requirement:/scenario: tags and tagged context wrappers"]
    end

    def normalise(path, text)
      squashed = remove_wrappers(text).gsub(TAG_PAIR, '').gsub(/\s+/, '')
      path == SPEC_HELPER ? squashed.sub(LOADER, '') : squashed
    end

    def remove_wrappers(text)
      offset = 0
      while (opener = WRAPPER.match(text, offset))
        text, offset = unwrap(text, opener)
      end
      text
    end

    # Removes one wrapper's opener and the `end` at its indentation. With no
    # matching `end` the text is left as is, so the comparison fails.
    def unwrap(text, opener)
      closer = /^#{Regexp.escape(opener[1])}end[ \t]*(?:\n|\z)/.match(text, opener.end(0))
      return [text, opener.end(0)] unless closer

      body = text[opener.end(0)...closer.begin(0)]
      [text[0...opener.begin(0)] + body + text[closer.end(0)..], opener.begin(0)]
    end
  end
end
