# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"
require "stringio"
require "aws_security_viz/cli"

describe AwsSecurityViz::Risk do
  def rule(protocol, from, to)
    AwsSecurityViz::Rule.new(protocol: protocol, from_port: from, to_port: to, peers: [])
  end

  def peer(kind, id) = AwsSecurityViz::Peer.new(kind: kind, id: id)

  let(:ports) { described_class::DEFAULT_PORTS }

  it "flags 0.0.0.0/0 and ::/0 on a sensitive port" do
    expect(described_class.risky?(rule("tcp", 22, 22), peer(:cidr4, "0.0.0.0/0"), ports)).to be true
    expect(described_class.risky?(rule("tcp", 3306, 3306), peer(:cidr6, "::/0"), ports)).to be true
  end

  it "flags a port range that covers a sensitive port and all-traffic rules" do
    expect(described_class.risky?(rule("tcp", 0, 65535), peer(:cidr4, "0.0.0.0/0"), ports)).to be true
    expect(described_class.risky?(rule("-1", nil, nil), peer(:cidr6, "::/0"), ports)).to be true
  end

  it "ignores other ports, udp, private peers and group peers" do
    expect(described_class.risky?(rule("tcp", 80, 80), peer(:cidr4, "0.0.0.0/0"), ports)).to be false
    expect(described_class.risky?(rule("udp", 22, 22), peer(:cidr4, "0.0.0.0/0"), ports)).to be false
    expect(described_class.risky?(rule("tcp", 22, 22), peer(:cidr4, "10.0.0.0/8"), ports)).to be false
    expect(described_class.risky?(rule("-1", nil, nil), peer(:group, "sg-1"), ports)).to be false
  end
end

describe "risk marking" do
  let(:fixture) { File.join(Dir.mktmpdir, "sgs.json") }
  let(:groups) {
    {"SecurityGroups" => [{"GroupId" => "sg-1", "GroupName" => "web", "VpcId" => "vpc-1", "IpPermissionsEgress" => [],
                           "IpPermissions" => [
                             {"IpProtocol" => "tcp", "FromPort" => 22, "ToPort" => 22, "IpRanges" => [{"CidrIp" => "0.0.0.0/0"}]},
                             {"IpProtocol" => "-1", "IpRanges" => [], "Ipv6Ranges" => [{"CidrIpv6" => "::/0"}]},
                             {"IpProtocol" => "tcp", "FromPort" => 80, "ToPort" => 80, "IpRanges" => [{"CidrIp" => "1.2.3.4/32"}]}
                           ]}]}
  }

  before do
    File.write(fixture, groups.to_json)
    allow(FileUtils).to receive(:copy)
  end

  def edges(config, renderer: "json")
    path = "#{fixture}.out.json"
    risky = AwsSecurityViz::VisualizeAws.new(config, source_file: fixture, renderer: renderer).unleash(path)
    [risky, JSON.parse(File.read(path))]
  end

  it "marks risky edges in json output, merged all label and ::/0 included" do
    count, json = edges(AwsSecurityViz::AwsConfig.new({}))
    expect(count).to eq(2)
    expect(json["edges"].select { |e| e["risky"] }.map { |e| e["source"] }).to contain_exactly("0.0.0.0/0", "::/0")
  end

  it "still flags risk with obfuscation on" do
    count, json = edges(AwsSecurityViz::AwsConfig.new(obfuscate: true))
    expect(count).to eq(2)
    expect(json["edges"].count { |e| e["risky"] }).to eq(2)
  end

  it "flags risk through a user group mapping of 0.0.0.0/0" do
    count, = edges(AwsSecurityViz::AwsConfig.new(groups: {"0.0.0.0/0" => "External"}))
    expect(count).to eq(2)
  end

  it "draws risky edges dashed crimson, distinct from the red egress colour, in DOT" do
    path = "#{fixture}.dot"
    AwsSecurityViz::VisualizeAws.new(AwsSecurityViz::AwsConfig.new({}), source_file: fixture, renderer: "graphviz").unleash(path)
    lines = File.read(path).lines
    expect(lines.grep(/0\.0\.0\.0\/0" ->/).first).to include('color="crimson"', 'style="dashed"', 'penwidth="3"')
    expect(lines.grep(/1\.2\.3\.4\/32" ->/).first).to include('color="blue"')
  end

  it "reads the port list from opts.yml (:risky_ports)" do
    count, = edges(AwsSecurityViz::AwsConfig.new(risky_ports: [80]))
    expect(count).to eq(1) # only the ::/0 all-traffic rule; port 22 is no longer listed
  end

  it "accepts decimal port numbers as integers or strings" do
    expect(AwsSecurityViz::AwsConfig.new(risky_ports: [22, "8080", 65535]).risky_ports).to eq([22, 8080, 65535])
  end

  ["0x16", "022x", 0, 65536, -1, 22.5, "", nil, "22 ", true].each do |bad|
    it "rejects risky_ports entry #{bad.inspect} when the config is built" do
      expect { AwsSecurityViz::AwsConfig.new(risky_ports: [22, bad]) }
        .to raise_error(ArgumentError, "risky_ports: invalid entry '#{bad}' (expected a port number 1-65535)")
    end
  end

  it "parses the list once" do
    config = AwsSecurityViz::AwsConfig.new(risky_ports: ["22"])
    expect(config.risky_ports).to equal(config.risky_ports)
  end
end

describe AwsSecurityViz::CLI, "--fail-on-risk" do
  let(:source) { File.expand_path("integration/dummy.json", __dir__) }
  let(:err) { StringIO.new }

  around { |example| Dir.mktmpdir { |dir| Dir.chdir(dir) { example.run } } }
  after { AwsSecurityViz.logger = nil }

  def run_cli(*argv) = described_class.new(argv, env: {}, out: StringIO.new, err: err).run

  it "prints a one-line summary and exits 0 without the flag" do
    expect(run_cli("-o", source, "-f", "x.json")).to eq(0)
    expect(err.string).to match(/\[WARN\] \d+ risky edge/)
    expect(err.string.lines.size).to eq(1)
  end

  it "exits 2 with the flag, still writing the output" do
    expect(run_cli("-o", source, "-f", "x.json", "--fail-on-risk")).to eq(2)
    expect(File.exist?("x.json")).to be true
  end

  it "reports an invalid risky_ports entry as a clean error" do
    File.write("opts.yml", {risky_ports: ["ssh"]}.to_yaml)
    expect(run_cli("-o", source, "-f", "x.json")).to eq(1)
    expect(err.string).to include("risky_ports: invalid entry 'ssh'")
  end

  it "exits 0 with the flag when nothing is risky" do
    File.write("opts.yml", {risky_ports: [1]}.to_yaml)
    expect(run_cli("-o", source, "-f", "x.json", "--fail-on-risk")).to eq(0)
    expect(err.string).to include("no risky public ingress")
  end
end
