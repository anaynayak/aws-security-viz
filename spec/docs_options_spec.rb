# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "aws_security_viz/cli"

describe "docs/configuration.md" do
  let(:page) { File.read(File.expand_path("../docs/configuration.md", __dir__)) }

  it "documents every long option printed by --help" do
    out = StringIO.new
    AwsSecurityViz::CLI.new(["--help"], env: {}, out: out, err: StringIO.new).run
    options = out.string.scan(/--(?:\[no-\])?[a-z-]+/).uniq
    expect(options).not_to be_empty
    missing = options.reject { |opt| page.include?(opt) }
    expect(missing).to eq([])
  end
end
