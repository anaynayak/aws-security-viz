# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

# Regression specs for known graph correctness bugs (B1-B4). Each is marked
# pending: it documents the bug and fails if the bug is fixed without removing
# the `pending` call. Un-pend each spec in the task that fixes its bug.
describe VisualizeAws do
  let(:fixture) { File.expand_path("fixtures/graph_bugs.json", __dir__) }
  let(:config) { AwsConfig.new({egress: true}) }
  let(:out_dir) { Dir.mktmpdir }
  let(:out_file) { File.join(out_dir, "out.json") }

  # While B4 is unfixed the html asset lands in the cwd; remove it if this example created it.
  let!(:stray_asset_existed) { File.exist?("navigator.html") }

  after do
    FileUtils.remove_entry(out_dir)
    FileUtils.rm_f("navigator.html") unless stray_asset_existed
  end

  def render(renderer)
    VisualizeAws.new(config, source_file: fixture, renderer: renderer).unleash(out_file)
    JSON.parse(File.read(out_file))
  end

  it "B1: keeps same-named groups in different VPCs as separate nodes" do
    pending "B1: nodes are keyed by group name, so the two 'default' groups merge"
    nodes = render("navigator")["data"]["nodes"]
    expect(nodes.count { |n| n["label"] == "default" }).to eq(2)
  end

  it "B2: keeps IPv6 ranges and prefix lists as rule peers" do
    pending "B2: Ipv6Ranges and PrefixListIds are ignored"
    labels = render("navigator")["data"]["nodes"].map { |n| n["label"] }
    expect(labels).to include("::/0", "pl-123")
  end

  it "B3: keeps the 5432/tcp label when an egress rule maps to the same edge" do
    pending "B3: the later egress rule overwrites the label with *"
    data = render("navigator")["data"]
    id_of = ->(label) { data["nodes"].find { |n| n["label"] == label }["id"] }
    edge = data["edges"].find { |e| e["from"] == id_of.call("app") && e["to"] == id_of.call("db") }
    expect(edge["label"]).to include("5432/tcp")
  end

  it "B4: writes the html asset next to the output file" do
    pending "B4: Renderer.copy_asset uses a nil @file_name and copies into the cwd"
    render("navigator")
    expect(File.exist?(File.join(out_dir, "navigator.html"))).to be(true)
  end
end
