# frozen_string_literal: true

# RepoTrace::TagOnlyDiff.call(path:, before:, after:) returns a list of problem
# strings (empty when the edit is allowed). It backs task 3.3 of
# adopt-live-docs: existing spec files may gain only requirement:/scenario:
# metadata, whitespace, and tagged context wrappers; spec/spec_helper.rb may
# also gain the spec/support loader block.
RSpec.describe 'RepoTrace::TagOnlyDiff' do
  let(:fixture_dir) { File.expand_path('../fixtures/tag_only', __dir__) }

  def problems_for(fixture, path: 'spec/domain/example_spec.rb')
    RepoTrace::TagOnlyDiff.call(path: path,
                                before: File.read(File.join(fixture_dir, fixture, 'before.rb')),
                                after: File.read(File.join(fixture_dir, fixture, 'after.rb')))
  end

  it 'allows added requirement:/scenario: pairs and the line wrapping they need' do
    expect(problems_for('tags_added')).to be_empty
  end

  it 'rejects a changed assertion and names the file' do
    expect(problems_for('assertion_changed')).to include(a_string_including('spec/domain/example_spec.rb'))
  end

  it 'allows a tagged context wrapper around unchanged lines' do
    expect(problems_for('wrapper_added')).to be_empty
  end

  it 'rejects a tagged context wrapper that also changes a line inside it' do
    expect(problems_for('wrapper_changes_inside')).to include(a_string_including('spec/domain/example_spec.rb'))
  end

  it 'allows the spec/support loader block in spec/spec_helper.rb' do
    expect(problems_for('spec_helper_loader', path: 'spec/spec_helper.rb')).to be_empty
  end

  it 'rejects the loader block in any file other than spec/spec_helper.rb' do
    expect(problems_for('spec_helper_loader')).to include(a_string_including('spec/domain/example_spec.rb'))
  end

  it 'rejects any other change to spec/spec_helper.rb' do
    expect(problems_for('spec_helper_other_change', path: 'spec/spec_helper.rb'))
      .to include(a_string_including('spec/spec_helper.rb'))
  end
end
