# frozen_string_literal: true

require "spec_helper"

# IPv6 ranges and prefix lists are rule peers just like IPv4 ranges.
class PeerRecorder
  attr_reader :output

  def initialize
    @output = []
    @labels = {}
  end

  def add_node(name, opts)
    @labels[name] = opts[:label] || name
    @output << [:node, @labels[name]]
  end

  def add_edge(from, to, opts)
    @output << [:edge, @labels.fetch(from, from), @labels.fetch(to, to), opts]
  end
end

describe AwsSecurityViz::VisualizeAws do
  let(:renderer) { PeerRecorder.new }

  def peer_ingress(port, ipv6: [], prefix_lists: [])
    {ip_ranges: [], ipv_6_ranges: ipv6.map { |c| {cidr_ipv_6: c} }, prefix_list_ids: prefix_lists.map { |p| {prefix_list_id: p} },
     user_id_group_pairs: [], ip_protocol: "tcp", from_port: port, to_port: port}
  end

  def edges(config)
    AwsSecurityViz::VisualizeAws.new(config).build.output(renderer).select { |o| o.first == :edge }
  end

  it "adds edges for IPv6 ranges and prefix lists from the AWS provider" do
    stub_security_groups([group("Web", peer_ingress(22, ipv6: ["::/0"], prefix_lists: ["pl-123"]))])
    expect(edges(AwsSecurityViz::AwsConfig.new)).to contain_exactly(
      [:edge, "::/0", "Web", {color: :blue, label: "22/tcp", risky: true}],
      [:edge, "pl-123", "Web", {color: :blue, label: "22/tcp"}]
    )
  end

  it "applies exclusions to IPv6 ranges and prefix lists" do
    stub_security_groups([group("Web", peer_ingress(22, ipv6: ["::/0", "2001:db8::/32"], prefix_lists: ["pl-123"]))])
    config = AwsSecurityViz::AwsConfig.new(exclude: ["^::/0$", "^pl-"])
    expect(edges(config).map { |e| e[1] }).to eq(["2001:db8::/32"])
  end

  it "applies CIDR group mapping to IPv6 ranges and prefix lists" do
    stub_security_groups([group("Web", peer_ingress(22, ipv6: ["::/0"], prefix_lists: ["pl-123"]))])
    config = AwsSecurityViz::AwsConfig.new(groups: {"::/0" => "Internet", "pl-123" => "Office"})
    expect(edges(config).map { |e| e[1] }).to contain_exactly("Internet", "Office")
  end

  it "adds edges for IPv6 ranges and prefix lists from the JSON provider" do
    fixture = File.expand_path("fixtures/graph_bugs.json", __dir__)
    expect(AwsSecurityViz::VisualizeAws.new(AwsSecurityViz::AwsConfig.new, source_file: fixture).build.output(renderer).map { |o| o[1] }).to include("::/0", "pl-123")
  end
end
