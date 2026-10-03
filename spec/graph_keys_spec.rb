# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

# Nodes are keyed by security group id, labelled with the group name, and grouped by VPC.
describe AwsSecurityViz::VisualizeAws do
  let(:fixture) { File.expand_path("fixtures/graph_bugs.json", __dir__) }
  let(:config) { AwsSecurityViz::AwsConfig.new({egress: true}) }
  let(:out_dir) { Dir.mktmpdir }
  let(:out_file) { File.join(out_dir, "out") }

  after { FileUtils.remove_entry(out_dir) }

  def render(renderer, extra = {})
    path = "#{out_file}.json"
    allow(FileUtils).to receive(:copy)
    AwsSecurityViz::VisualizeAws.new(config, {source_file: fixture, renderer: renderer}.merge(extra)).unleash(path)
    JSON.parse(File.read(path))
  end

  it "keys json nodes by group id and labels them with the name" do
    nodes = render("json")["nodes"]
    expect(nodes.select { |n| n["label"] == "default" }.map { |n| n["id"] }).to contain_exactly("sg-default-a", "sg-default-b")
    expect(nodes).to include({"id" => "sg-app", "label" => "app"})
  end

  it "keys navigator edges by group id" do
    edge = render("navigator")["data"]["edges"].find { |e| e["from"] == "sg-app" }
    expect(edge["to"]).to eq("sg-db")
  end

  it "draws one dot cluster per vpc with separate default nodes" do
    dot = out_file + ".dot"
    AwsSecurityViz::VisualizeAws.new(config, source_file: fixture, renderer: "graphviz").unleash(dot)
    content = File.read(dot)
    expect(content.scan(/subgraph "?cluster_vpc-[ab]"?/).size).to eq(2)
    expect(content).to match(/subgraph "cluster_vpc-a".*"sg-default-a"\s*\[.*?label="?default/m)
    expect(content).to match(/subgraph "cluster_vpc-b".*"sg-default-b"\s*\[.*?label="?default/m)
  end

  it "accepts a group name or id as a source filter" do
    by_name = render("json", source_filter: "app")["nodes"].map { |n| n["id"] }
    by_id = render("json", source_filter: "sg-app")["nodes"].map { |n| n["id"] }
    expect(by_name).to match_array(by_id)
    expect(by_id).to include("sg-app", "sg-db")
  end

  it "accepts a group name or id as a target filter" do
    by_name = render("json", target_filter: "db")["nodes"].map { |n| n["id"] }
    expect(by_name).to include("sg-app", "sg-db")
    expect(render("json", target_filter: "sg-db")["nodes"].map { |n| n["id"] }).to match_array(by_name)
  end

  it "rejects a filter name shared by several groups" do
    expect { render("json", source_filter: "default") }.to raise_error(ArgumentError, /sg-default-a.*sg-default-b/)
  end

  it "rejects a filter that matches no group or peer" do
    expect { render("json", source_filter: "nope") }.to raise_error(ArgumentError, "no group or peer matches 'nope'")
    expect { render("json", target_filter: "nope") }.to raise_error(ArgumentError, "no group or peer matches 'nope'")
  end

  it "shows hashed ids, not real ones, in the ambiguous filter error under obfuscation" do
    config = AwsSecurityViz::AwsConfig.new({egress: true, obfuscate: true})
    expect {
      AwsSecurityViz::VisualizeAws.new(config, source_file: fixture, renderer: "json", source_filter: "default")
        .unleash("#{out_file}.json")
    }.to raise_error(ArgumentError) { |e|
      expect(e.message).to match(/matches several groups/)
      expect(e.message).not_to match(/sg-default/)
      expect(e.message).to include(AwsSecurityViz::Obfuscation.hash("sg-default-a"))
    }
  end
end

describe AwsSecurityViz::Graph, "filters on degenerate shapes" do
  let(:graph) {
    described_class.new(AwsSecurityViz::AwsConfig.new({})).tap { |g|
      %w[a b c].each { |n| g.add_node(n, {label: n}) }
      g.add_edge("a", "b", label: "80/tcp")
      g.add_edge("b", "b", label: "22/tcp")
      g.add_edge("b", "c", label: "443/tcp")
    }
  }

  it "keeps only the node itself when source == target and no cycle returns to it" do
    expect(graph.filter("a", "a").vertices).to eq(["a"])
    expect(graph.underlying.edges).to be_empty
  end

  it "keeps a self-loop edge when source == target is the looping node" do
    filtered = graph.filter("b", "b")
    expect(filtered.vertices).to eq(["b"])
    expect(filtered.edges.map { |e| [e.source, e.target] }).to eq([%w[b b]])
  end

  it "retains a self-loop on an intermediate node" do
    expect(graph.filter("a", "c").edges.map { |e| [e.source, e.target] }).to include(%w[b b])
  end
end
