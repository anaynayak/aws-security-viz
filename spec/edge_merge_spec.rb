# frozen_string_literal: true

require "spec_helper"
require "digest"
require "tmpdir"

# Several rules can map to one edge; the merged label and colour must not depend on rule order.
describe Graph do
  let(:config) { AwsConfig.new({}) }
  let(:graph) { Graph.new(config) }
  let(:renderer) do
    Class.new {
      attr_reader :edges

      def initialize = @edges = {}

      def add_node(name, opts)
      end

      def add_edge(from, to, opts) = @edges[[from, to]] = opts

      def output
      end
    }.new
  end

  def edge(from, to, color, label)
    graph.add_edge(from, to, color: color, label: label)
  end

  def rendered
    graph.output(renderer)
    renderer.edges.fetch(["a", "b"])
  end

  it "deduplicates and sorts labels numerically by port, then protocol" do
    edge("a", "b", :blue, "443/tcp,22/tcp")
    edge("a", "b", :blue, "80/udp,22/tcp,80/tcp")
    expect(rendered[:label]).to eq("22/tcp,80/tcp,80/udp,443/tcp")
  end

  it "collapses to * when all traffic is present" do
    edge("a", "b", :blue, "22/tcp")
    edge("a", "b", :red, "*")
    expect(rendered[:label]).to eq("*")
  end

  it "is blue when any merged rule is ingress, whichever came first" do
    edge("a", "b", :red, "22/tcp")
    edge("a", "b", :blue, "80/tcp")
    expect(rendered[:color]).to eq(:blue)
  end

  it "keeps one deterministic colour in colour mode" do
    edge("a", "b", "#cc0000", "22/tcp")
    edge("a", "b", "#00004c", "80/tcp")
    expect(rendered[:color]).to eq("#00004c")
  end

  it "merges hashed port tokens and collapses the hashed wildcard" do
    h = ->(t) { Digest::SHA256.hexdigest(t) }
    obfuscated = DebugGraph.new(AwsConfig.new({}))
    obfuscated.add_edge("a", "b", color: :blue, label: "22/tcp,80/tcp")
    obfuscated.add_edge("a", "b", color: :red, label: "22/tcp")
    obfuscated.output(renderer)
    label = renderer.edges.fetch([h.call("a"), h.call("b")])[:label]
    expect(label.split(",")).to match_array([h.call("22/tcp"), h.call("80/tcp")])

    obfuscated.add_edge("a", "b", color: :red, label: "*")
    obfuscated.output(renderer)
    expect(renderer.edges.fetch([h.call("a"), h.call("b")])[:label]).to eq(h.call("*"))
  end
end

describe VisualizeAws do
  let(:config) { AwsConfig.new({egress: true}) }
  let(:out_dir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(out_dir) }

  def group(id, name, ingress: [], egress: [])
    {"GroupName" => name, "GroupId" => id, "VpcId" => "vpc-1", "IpPermissions" => ingress, "IpPermissionsEgress" => egress}
  end

  def rule(proto, from, to, peer)
    {"IpProtocol" => proto, "FromPort" => from, "ToPort" => to, "IpRanges" => [], "Ipv6Ranges" => [], "PrefixListIds" => [],
     "UserIdGroupPairs" => [{"GroupId" => peer, "GroupName" => peer, "UserId" => "o"}]}
  end

  def edges_for(groups, extra = {})
    source = File.join(out_dir, "in.json")
    File.write(source, {"SecurityGroups" => groups}.to_json)
    graph = VisualizeAws.new(config, {source_file: source}.merge(extra)).build
    recorded = {}
    recorder = Struct.new(:edges) {
      def add_node(*)
      end

      def add_edge(from, to, opts) = edges[[from, to]] = opts

      def output
      end
    }.new(recorded)
    graph.output(recorder)
    recorded
  end

  it "merges two ingress rules on one edge in numeric order" do
    groups = [group("sg-db", "db", ingress: [rule("tcp", 5432, 5432, "sg-app"), rule("tcp", 80, 80, "sg-app"), rule("udp", 53, 53, "sg-app")])]
    edge = edges_for(groups).fetch(["sg-app", "sg-db"])
    expect(edge[:label]).to eq("53/udp,80/tcp,5432/tcp")
    expect(edge[:color]).to eq(:blue)
  end

  it "keeps the edge blue when the egress group comes first" do
    app = group("sg-app", "app", egress: [rule("tcp", 5432, 5432, "sg-db")])
    db = group("sg-db", "db", ingress: [rule("tcp", 80, 80, "sg-app")])
    [[app, db], [db, app]].each do |groups|
      edge = edges_for(groups).fetch(["sg-app", "sg-db"])
      expect(edge[:color]).to eq(:blue)
      expect(edge[:label]).to eq("80/tcp,5432/tcp")
    end
  end
end
