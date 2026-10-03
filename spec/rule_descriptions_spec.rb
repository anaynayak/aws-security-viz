# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"

# Rule descriptions explain why a rule exists: JSON edges list them, DOT edges show them as tooltips.
describe "rule descriptions" do
  let(:tricky) { %(office "VPN" \\N\nline2) }

  def cli_group(descriptions)
    {"GroupId" => "sg-1", "GroupName" => "Web", "VpcId" => "vpc-1", "IpPermissionsEgress" => [],
     "IpPermissions" => [
       {"IpProtocol" => "tcp", "FromPort" => 22, "ToPort" => 22,
        "IpRanges" => [{"CidrIp" => "10.0.0.0/8", "Description" => descriptions[0]}],
        "Ipv6Ranges" => [], "PrefixListIds" => [],
        "UserIdGroupPairs" => [{"GroupId" => "sg-2", "Description" => descriptions[1]}]}
     ]}
  end

  def build(provider, obfuscate: false)
    config = AwsSecurityViz::AwsConfig.new(obfuscate: obfuscate)
    AwsSecurityViz::VisualizeAws.new(config, provider).build.then { |graph| [graph, config] }
  end

  def render(klass, graph, config, file)
    graph.output(klass.new(file, config))
  end

  def from_json_provider(descriptions)
    file = File.join(@dir, "in.json")
    File.write(file, {"SecurityGroups" => [cli_group(descriptions)]}.to_json)
    {source_file: file}
  end

  def from_ec2_provider(descriptions)
    client = Aws::EC2::Client.new(stub_responses: true, region: "us-east-1")
    client.stub_responses(:describe_security_groups, security_groups: [
      {group_id: "sg-1", group_name: "Web", vpc_id: "vpc-1", ip_permissions: [
        {ip_protocol: "tcp", from_port: 22, to_port: 22,
         ip_ranges: [{cidr_ip: "10.0.0.0/8", description: descriptions[0]}],
         user_id_group_pairs: [{group_id: "sg-2", description: descriptions[1]}]}
      ]}
    ])
    allow(Aws::EC2::Client).to receive(:new).and_return(client)
    {region: "us-east-1"}
  end

  around do |example|
    Dir.mktmpdir { |dir|
      @dir = dir
      example.run
    }
  end

  {json: :from_json_provider, ec2: :from_ec2_provider}.each do |name, factory|
    context "with the #{name} provider" do
      let(:options) { send(factory, [tricky, "from app tier"]) }

      it "lists descriptions per rule on JSON edges" do
        graph, config = build(options)
        file = File.join(@dir, "out.json")
        render(AwsSecurityViz::Renderer::Json, graph, config, file)
        edges = JSON.parse(File.read(file))["edges"].to_h { |e| [e["source"], e] }
        expect(edges["10.0.0.0/8"]["descriptions"]).to eq([{"ports" => "22/tcp", "text" => tricky}])
        expect(edges["sg-2"]["descriptions"]).to eq([{"ports" => "22/tcp", "text" => "from app tier"}])
      end

      it "writes escaped DOT tooltips" do
        graph, config = build(options)
        dot = render(AwsSecurityViz::Renderer::GraphViz, graph, config, File.join(@dir, "out.dot")) && File.read(File.join(@dir, "out.dot"))
        expect(dot).to include(%(tooltip="22/tcp: office \\"VPN\\" \\\\N\\nline2"))
        expect(dot).to include('tooltip="22/tcp: from app tier"')
      end

      it "hashes descriptions under obfuscation" do
        graph, config = build(options, obfuscate: true)
        file = File.join(@dir, "out.json")
        render(AwsSecurityViz::Renderer::Json, graph, config, file)
        expect(File.read(file)).not_to include("office", "from app tier", "22/tcp")
        expect(JSON.parse(File.read(file))["edges"].map { |e| e["descriptions"].first["text"] }).to all(match(/\A\h{10}\z/))
      end
    end
  end

  it "omits descriptions and tooltips when rules have none" do
    graph, config = build(from_json_provider([nil, ""]))
    json = File.join(@dir, "o.json")
    dot = File.join(@dir, "o.dot")
    render(AwsSecurityViz::Renderer::Json, graph, config, json)
    render(AwsSecurityViz::Renderer::GraphViz, graph, config, dot)
    expect(File.read(json)).not_to include("descriptions")
    expect(File.read(dot)).not_to include("tooltip")
  end

  it "unions descriptions of rules merged into one edge" do
    file = File.join(@dir, "in.json")
    rule = ->(port, text) { {"IpProtocol" => "tcp", "FromPort" => port, "ToPort" => port, "IpRanges" => [{"CidrIp" => "10.0.0.0/8", "Description" => text}]} }
    File.write(file, {"SecurityGroups" => [{"GroupId" => "sg-1", "GroupName" => "Web", "VpcId" => "v", "IpPermissions" => [rule.call(22, "ssh"), rule.call(80, "http")]}]}.to_json)
    graph, config = build({source_file: file})
    out = File.join(@dir, "m.json")
    render(AwsSecurityViz::Renderer::Json, graph, config, out)
    expect(JSON.parse(File.read(out))["edges"].first["descriptions"].map { |d| d["text"] }).to eq(%w[ssh http])
  end
end
