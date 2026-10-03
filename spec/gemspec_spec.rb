# frozen_string_literal: true

require "spec_helper"

RSpec.describe "aws_security_viz.gemspec" do
  let(:root) { File.expand_path("..", __dir__) }
  let(:spec) { Gem::Specification.load(File.join(root, "aws_security_viz.gemspec")) }

  it "does not cap runtime dependencies" do
    uncapped = spec.runtime_dependencies.all? do |dep|
      dep.requirement.requirements.all? { |op, _| op == ">=" }
    end
    expect(uncapped).to be(true)
  end

  it "requires Ruby 3.3 or newer" do
    expect(spec.required_ruby_version.to_s).to eq(">= 3.3")
  end

  it "packages only runtime files and docs" do
    expect(spec.files.reject { |f| File.directory?(File.join(root, f)) }).to all(match(%r{\A(lib/|exe/|LICENSE\.md\z|README\.md\z|CHANGELOG\.md\z)}))
  end

  it "packages the executable, option sample" do
    expect(spec.files).to include("exe/aws_security_viz", "lib/aws_security_viz/opts.yml.sample")
  end

  it "packages the html viewer template and the vendored Cytoscape.js with its license and provenance" do
    expect(spec.files).to include(
      "lib/aws_security_viz/export/html/viewer.html",
      "lib/aws_security_viz/vendor/cytoscape/cytoscape.min.js",
      "lib/aws_security_viz/vendor/cytoscape/LICENSE",
      "lib/aws_security_viz/vendor/cytoscape/README.md"
    )
  end

  it "declares release metadata and no build-time fields" do
    expect(spec.metadata).to include("rubygems_mfa_required" => "true", "source_code_uri" => a_string_starting_with("https://"), "changelog_uri" => a_string_starting_with("https://"))
    expect(spec.test_files).to be_empty
  end
end
