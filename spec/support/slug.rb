# frozen_string_literal: true

module RepoTrace
  # The slug rule shared by every greeterHQ repo: lowercase the heading text,
  # replace each run of characters other than a-z and 0-9 with one "-", and
  # trim "-" from both ends. No camel-case splitting.
  module Slug
    module_function

    def call(text)
      text.to_s.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')
    end
  end
end
