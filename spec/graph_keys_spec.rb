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
    expect(content).to match(/subgraph "cluster_vpc-a".*"sg-default-a"\s*\[.*?label=default/m)
    expect(content).to match(/subgraph "cluster_vpc-b".*"sg-default-b"\s*\[.*?label=default/m)
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
end
