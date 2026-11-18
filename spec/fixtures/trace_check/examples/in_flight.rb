# frozen_string_literal: true

# Trace-check fixture: tags for headings that live in change deltas.
FIXTURE_TAGS = [
  { requirement: 'delta-added', scenario: 'delta-works' },
  { requirement: 'alpha-covered', scenario: 'alpha-also-works' },
  { requirement: 'archived-only', scenario: 'archived-works' },
  { requirement: 'removed-thing', scenario: 'removed-works' },
  { requirement: 'new-name', scenario: 'new-name' }
].freeze
