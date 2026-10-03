# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

# Regression specs for graph correctness bugs B1-B4, all fixed; each guards its fix.
describe AwsSecurityViz::VisualizeAws do
  let(:fixture) { File.expand_path("fixtures/graph_bugs.json", __dir__) }
  let(:config) { AwsSecurityViz::AwsConfig.new({egress: true}) }
  let(:out_dir) { Dir.mktmpdir }
  let(:out_file) { File.join(out_dir, "out.json") }

  after { FileUtils.remove_entry(out_dir) }

  def render(renderer)
    AwsSecurityViz::VisualizeAws.new(config, source_file: fixture, renderer: renderer).unleash(out_file)
    JSON.parse(File.read(out_file))
  end

  it "B1: keeps same-named groups in different VPCs as separate nodes" do
    nodes = render("json")["nodes"]
    expect(nodes.count { |n| n["label"] == "default" }).to eq(2)
  end

  it "B2: keeps IPv6 ranges and prefix lists as rule peers" do
    labels = render("json")["nodes"].map { |n| n["label"] }
    expect(labels).to include("::/0", "pl-123")
  end

  it "B3: merges the ingress 5432/tcp rule and the egress all-traffic rule into one edge" do
    data = render("json")
    id_of = ->(label) { data["nodes"].find { |n| n["label"] == label }["id"] }
    edge = data["edges"].find { |e| e["source"] == id_of.call("app") && e["target"] == id_of.call("db") }
    expect(edge["label"]).to eq("all")
  end

  it "B4: writes no helper html next to the output file or in the cwd" do
    render("json")
    expect(Dir.children(out_dir)).to eq(["out.json"])
    expect(File.exist?("navigator.html")).to be(false)
  end
end
