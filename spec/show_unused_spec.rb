# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "tmpdir"
require "json"
require "aws_security_viz/cli"

describe "--show-unused" do
  def group(id)
    {group_id: id, group_name: id, vpc_id: "vpc-1", ip_permissions: [], ip_permissions_egress: []}
  end

  def eni(*ids)
    {groups: ids.map { |id| {group_id: id, group_name: id} }}
  end

  let(:client) { Aws::EC2::Client.new(stub_responses: true, region: "us-east-1") }

  describe AwsSecurityViz::Ec2Provider do
    before do
      client.stub_responses(:describe_security_groups, security_groups: [group("sg-1"), group("sg-2"), group("sg-3")])
    end

    it "flags groups with no network interface, reading every ENI page" do
      client.stub_responses(:describe_network_interfaces, [
        {network_interfaces: [eni("sg-1")], next_token: "t"},
        {network_interfaces: [eni("sg-3", "sg-1")]}
      ])
      groups = described_class.new({show_unused: true}, client: client).security_groups
      expect(groups.to_h { |g| [g.id, g.unused] }).to eq("sg-1" => false, "sg-2" => true, "sg-3" => false)
    end

    it "keeps the groups and warns when DescribeNetworkInterfaces is not permitted" do
      client.stub_responses(:describe_network_interfaces, "UnauthorizedOperation")
      err = StringIO.new
      AwsSecurityViz.logger = AwsSecurityViz.build_logger(err)
      groups = described_class.new({show_unused: true}, client: client).security_groups
      expect(groups.map(&:id)).to eq(%w[sg-1 sg-2 sg-3])
      expect(groups.map(&:unused)).to eq([false, false, false])
      expect(err.string).to include("--show-unused needs ec2:DescribeNetworkInterfaces")
    ensure
      AwsSecurityViz.logger = nil
    end

    it "makes no network interface call without the flag" do
      calls = []
      client.handle(step: :initialize) { |ctx|
        calls << ctx.operation_name
        @handler.call(ctx)
      }
      groups = described_class.new({}, client: client).security_groups
      expect(calls).to eq([:describe_security_groups])
      expect(groups.map(&:unused)).to eq([false, false, false])
    end

    it "applies the vpc filter to the network interface call" do
      seen = nil
      client.handle(step: :initialize) { |ctx|
        seen = ctx.params[:filters] if ctx.operation_name == :describe_network_interfaces
        @handler.call(ctx)
      }
      described_class.new({show_unused: true, vpc_id: "vpc-1"}, client: client).security_groups
      expect(seen).to eq([{name: "vpc-id", values: ["vpc-1"]}])
    end

    it "decides per region" do
      allow(Aws::EC2::Client).to receive(:new).and_wrap_original { |original, opts|
        original.call(region: opts[:region], stub_responses: {
          describe_security_groups: {security_groups: [group("sg-a")]},
          describe_network_interfaces: {network_interfaces: (opts[:region] == "eu-west-1") ? [eni("sg-a")] : []}
        })
      }
      groups = described_class.new({show_unused: true, region: "eu-west-1,us-west-2"}).security_groups
      expect(groups.map { |g| [g.region, g.unused] }).to eq([["eu-west-1", false], ["us-west-2", true]])
    end
  end

  describe "renderers" do
    let(:nodes) { [["sg-1", {label: "used"}], ["sg-2", {label: "idle", unused: true}]] }

    def render(klass, file)
      config = AwsSecurityViz::AwsConfig.new({})
      graph = AwsSecurityViz::Graph.new(config)
      nodes.each { |id, opts| graph.add_node(id, opts) }
      graph.output(klass.new(file, config))
    end

    around { |ex| Dir.mktmpdir { |dir| Dir.chdir(dir) { ex.run } } }

    it "styles unused nodes in DOT only" do
      render(AwsSecurityViz::Renderer::GraphViz, "o.dot")
      dot = File.read("o.dot")
      expect(dot).to match(/"sg-2" \[label="idle", style="dashed,filled"/)
      expect(dot).to match(/"sg-1" \[label="used"\];/)
    end

    it "classes unused nodes in Mermaid" do
      render(AwsSecurityViz::Renderer::Mermaid, "o.mmd")
      mmd = File.read("o.mmd")
      expect(mmd).to include("classDef unused", "class n1 unused")
      expect(mmd).not_to include("n0 unused")
    end

    it "emits no classDef when nothing is unused" do
      nodes.last[1].delete(:unused)
      render(AwsSecurityViz::Renderer::Mermaid, "o.mmd")
      expect(File.read("o.mmd")).not_to include("unused")
    end

    it "flags unused nodes in JSON output" do
      render(AwsSecurityViz::Renderer::Json, "o.json")
      expect(JSON.parse(File.read("o.json"))["nodes"].map { |n| n["unused"] }).to eq([nil, true])
    end

    it "keeps the flag readable under obfuscation" do
      config = AwsSecurityViz::AwsConfig.new(obfuscate: true)
      graph = AwsSecurityViz::Graph.new(config)
      nodes.each { |id, opts| graph.add_node(id, opts) }
      graph.output(AwsSecurityViz::Renderer::Json.new("o.json", config))
      expect(JSON.parse(File.read("o.json"))["nodes"].map { |n| n["unused"] }).to eq([nil, true])
    end
  end

  describe AwsSecurityViz::CLI do
    let(:err) { StringIO.new }

    around { |ex| Dir.mktmpdir { |dir| Dir.chdir(dir) { ex.run } } }
    after { AwsSecurityViz.logger = nil }

    it "warns and ignores the flag with --source-file" do
      source = File.expand_path("integration/dummy.json", __dir__)
      expect(Aws::EC2::Client).not_to receive(:new)
      status = described_class.new(["--show-unused", "-o", source, "-f", "o.json"],
        env: {}, out: StringIO.new, err: err).run
      expect(status).to eq(0)
      expect(err.string).to include("--show-unused is ignored with --source-file")
      expect(JSON.parse(File.read("o.json"))["nodes"].map { |n| n["unused"] }.compact).to be_empty
    end
  end
end
