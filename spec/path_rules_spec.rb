# frozen_string_literal: true

require "spec_helper"

# The viewer's "can X reach Y" query works from the rules each group carries, not from the drawn edges.
describe AwsSecurityViz::SecurityGroups, "#path_rules" do
  let(:udp_egress) { {ip_ranges: [{cidr_ip: "10.0.0.0/8", description: " to the office "}], ip_protocol: "17", from_port: 53, to_port: 53} }
  let(:web) {
    {group_name: "web", group_id: "sg-web", vpc_id: "vpc-1",
     ip_permissions: [group_ingress(443, "lb"), cidr_ingress(22, "0.0.0.0/0")],
     ip_permissions_egress: [udp_egress, {user_id_group_pairs: [{group_id: "sg-db"}], ip_protocol: "-1"}]}
  }
  let(:db) { {group_name: "db", group_id: "sg-db", vpc_id: "vpc-1", ip_permissions: [], ip_permissions_egress: []} }

  def rules_of(config, group_id = "sg-web")
    stub_security_groups([web, db])
    provider = AwsSecurityViz::Ec2Provider.new({})
    groups = described_class.new(provider, config)
    groups.path_rules(groups.find { |g| g.id == group_id })
  end

  it "lists ingress and egress rules with direction, protocol, ports, peer kind, peer and description" do
    rules = rules_of(AwsSecurityViz::AwsConfig.new({}))
    expect(rules).to include(
      {dir: "in", proto: "tcp", from: 443, to: 443, kind: "group", peer: "sg-lb"},
      {dir: "in", proto: "tcp", from: 22, to: 22, kind: "cidr4", peer: "0.0.0.0/0"},
      {dir: "out", proto: "udp", from: 53, to: 53, kind: "cidr4", peer: "10.0.0.0/8", desc: "to the office"},
      {dir: "out", proto: "all", kind: "group", peer: "sg-db"}
    )
  end

  it "keeps egress rules even when egress edges are not drawn" do
    expect(rules_of(AwsSecurityViz::AwsConfig.new(egress: false)).count { |r| r[:dir] == "out" }).to eq(2)
  end

  it "names the node a mapped CIDR is drawn as, and leaves out excluded peers" do
    config = AwsSecurityViz::AwsConfig.new(groups: {"10.0.0.0/8" => "office"}, exclude: ["lb"])
    rules = rules_of(config)
    expect(rules).to include(a_hash_including(peer: "10.0.0.0/8", node: "office"))
    expect(rules.map { |r| r[:peer] }).not_to include("sg-lb")
  end

  it "reaches the html data of each group and not the json output" do
    stub_security_groups([web, db])
    config = AwsSecurityViz::AwsConfig.new({})
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        recorded = []
        renderer = Class.new {
          define_method(:add_node) { |id, opts| recorded << [id, opts] }
          define_method(:add_edge) { |*| }
          define_method(:output) {}
        }.new
        AwsSecurityViz::VisualizeAws.new(config).build.output(renderer)
        expect(recorded.to_h.fetch("sg-web")[:rules].size).to eq(4)
        AwsSecurityViz::VisualizeAws.new(config).build.output(AwsSecurityViz::Renderer::Json.new("o.json", config))
        expect(File.read("o.json")).not_to include("rules")
      end
    end
  end

  it "marks a direction the input has no rule list for, which is not an empty list" do
    fixture = File.expand_path("fixtures/path_adversarial.json", __dir__)
    recorded = {}
    renderer = Class.new {
      define_method(:add_node) { |id, opts| recorded[id] = opts }
      define_method(:add_edge) { |*| }
      define_method(:output) {}
    }.new
    AwsSecurityViz::VisualizeAws.new(AwsSecurityViz::AwsConfig.new({}), source_file: fixture).build.output(renderer)
    expect(recorded.fetch("sg-nokey")[:unknown]).to eq(["out"])
    expect(recorded.fetch("sg-noeg")).not_to have_key(:unknown)
  end
end
