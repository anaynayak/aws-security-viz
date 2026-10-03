# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

# Regression specs for graph correctness bugs B1-B4, all fixed; each guards its fix.
describe VisualizeAws do
  let(:fixture) { File.expand_path("fixtures/graph_bugs.json", __dir__) }
  let(:config) { AwsConfig.new({egress: true}) }
  let(:out_dir) { Dir.mktmpdir }
  let(:out_file) { File.join(out_dir, "out.json") }

  # Remember any navigator.html already in the cwd so a B4 regression can be told apart from it.
  let!(:cwd_asset_before) { File.exist?("navigator.html") && [File.mtime("navigator.html"), File.read("navigator.html")] }

  after do
    FileUtils.remove_entry(out_dir)
    FileUtils.rm_f("navigator.html") unless cwd_asset_before
  end

  def render(renderer)
    VisualizeAws.new(config, source_file: fixture, renderer: renderer).unleash(out_file)
    JSON.parse(File.read(out_file))
  end

  it "B1: keeps same-named groups in different VPCs as separate nodes" do
    nodes = render("navigator")["data"]["nodes"]
    expect(nodes.count { |n| n["label"] == "default" }).to eq(2)
  end

  it "B2: keeps IPv6 ranges and prefix lists as rule peers" do
    labels = render("navigator")["data"]["nodes"].map { |n| n["label"] }
    expect(labels).to include("::/0", "pl-123")
  end

  it "B3: merges the ingress 5432/tcp rule and the egress all-traffic rule into one edge" do
    data = render("navigator")["data"]
    id_of = ->(label) { data["nodes"].find { |n| n["label"] == label }["id"] }
    edge = data["edges"].find { |e| e["from"] == id_of.call("app") && e["to"] == id_of.call("db") }
    expect(edge["label"]).to eq("*")
  end

  it "B4: writes the html asset next to the output file" do
    render("navigator")
    expect(File.exist?(File.join(out_dir, "navigator.html"))).to be(true)
    cwd_asset_after = File.exist?("navigator.html") && [File.mtime("navigator.html"), File.read("navigator.html")]
    expect(cwd_asset_after).to eq(cwd_asset_before)
  end
end
