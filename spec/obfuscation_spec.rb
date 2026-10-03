# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

describe AwsSecurityViz::Obfuscation do
  let(:source) { File.expand_path("integration/dummy.json", __dir__) }

  %w[json navigator graphviz].each do |renderer|
    it "leaves no vpc- or sg- ids in #{renderer} output" do
      Dir.mktmpdir { |dir|
        out = File.join(dir, (renderer == "graphviz") ? "o.dot" : "o.json")
        config = AwsSecurityViz::AwsConfig.new(obfuscate: true)
        AwsSecurityViz::VisualizeAws.new(config, source_file: source, renderer: renderer).unleash(out)
        expect(File.read(out)).not_to match(/vpc-|sg-/)
      }
    end
  end

  it "hashes vpc_id and group_id node metadata" do
    nodes, = described_class.apply([["sg-1", {label: "web", vpc_id: "vpc-1", group_id: "sg-1"}]], [])
    expect(nodes.first.last.values.join).not_to match(/vpc-|sg-|web/)
  end
end
