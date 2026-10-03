# frozen_string_literal: true

require "spec_helper"

describe PortLabel do
  describe ".format" do
    {
      ["-1", nil, nil] => "all",
      ["-1", -1, -1] => "all",
      ["tcp", 22, 22] => "22/tcp",
      ["tcp", 1024, 65535] => "1024-65535/tcp",
      ["udp", 53, 53] => "53/udp",
      ["icmp", -1, -1] => "icmp",
      ["icmp", 8, -1] => "icmp 8",
      ["icmp", 3, 4] => "icmp 3/4",
      ["icmpv6", -1, -1] => "icmpv6",
      ["50", nil, nil] => "proto 50",
      ["6", 80, 80] => "80/tcp",
      ["1", -1, -1] => "icmp"
    }.each do |(protocol, from, to), label|
      it "renders #{protocol} #{from.inspect} #{to.inspect} as #{label}" do
        expect(PortLabel.format(protocol, from, to)).to eq(label)
      end
    end
  end

  it "lets all swallow other tokens when normalising" do
    expect(PortLabel.normalise("22/tcp,all,icmp")).to eq("all")
  end

  it "sorts non-port tokens after ports" do
    expect(PortLabel.normalise("proto 50,22/tcp,icmp")).to eq("22/tcp,icmp,proto 50")
  end

  it "labels icmp and numeric-protocol rules in the built graph" do
    perms = [
      {ip_ranges: [{cidr_ip: "10.0.0.0/8"}], user_id_group_pairs: [], ip_protocol: "icmp", from_port: -1, to_port: -1},
      {ip_ranges: [{cidr_ip: "10.0.0.0/8"}], user_id_group_pairs: [], ip_protocol: "50"}
    ]
    stub_security_groups([group("Web", *perms)])
    labels = []
    renderer = Class.new {
      define_method(:add_node) { |*| }
      define_method(:add_edge) { |_from, _to, opts| labels << opts[:label] }
      define_method(:output) {}
    }.new
    VisualizeAws.new(AwsConfig.new).build.output(renderer)
    expect(labels).to eq(["icmp,proto 50"])
  end
end
