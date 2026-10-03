# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

describe AwsSecurityViz::Obfuscation do
  let(:source) { File.expand_path("integration/dummy.json", __dir__) }

  %w[json html graphviz mermaid].each do |renderer|
    it "leaves no vpc- or sg- ids in #{renderer} output" do
      Dir.mktmpdir { |dir|
        out = File.join(dir, {"graphviz" => "o.dot", "mermaid" => "o.mmd", "html" => "o.html"}.fetch(renderer, "o.json"))
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

describe AwsSecurityViz::Graph, "debug logging under obfuscation" do
  it "logs hashed ids, names and vpc ids, never the real ones" do
    config = AwsSecurityViz::AwsConfig.new(debug: true, obfuscate: true)
    graph = described_class.new(config)
    out = capture_log {
      graph.add_node("sg-1", {label: "web", vpc_id: "vpc-1", group_id: "sg-1"})
      graph.add_edge("sg-1", "10.0.0.0/8", {label: "80", color: :blue})
    }
    expect(out).to include("node:", "edge:")
    expect(out).not_to match(/sg-|vpc-|web|10\.0/)
  end

  def capture_log
    io = StringIO.new
    AwsSecurityViz.logger = AwsSecurityViz.build_logger(io)
    yield
    io.string
  ensure
    AwsSecurityViz.logger = nil
  end
end
