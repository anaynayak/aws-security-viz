# frozen_string_literal: true

require "spec_helper"

describe "provider model" do
  let(:fixture) { File.expand_path("fixtures/graph_bugs.json", __dir__) }

  def peer_ingress(group_pair)
    {ip_ranges: [], user_id_group_pairs: [group_pair], ip_protocol: "tcp", from_port: 22, to_port: 22}
  end

  it "returns the same Data structs from the JSON and AWS providers" do
    json = AwsSecurityViz::JsonProvider.new(source_file: fixture).security_groups
    raw = JSON.parse(File.read(fixture))["SecurityGroups"]
    client = Aws::EC2::Client.new(stub_responses: {describe_security_groups: {security_groups: aws_shape(raw)}}, region: "us-east-1")
    aws = AwsSecurityViz::Ec2Provider.new({}, client: client).security_groups
    expect(json).to all(be_a(AwsSecurityViz::SecurityGroup))
    expect(aws).to eq(json)
    expect(json.flat_map { |g| g.ingress + g.egress }.flat_map(&:peers).map(&:kind).uniq).to include(:cidr6, :prefix_list, :group)
  end

  it "excludes a group peer by name when EC2 omits GroupName" do
    stub_security_groups([group("Web", peer_ingress(group_id: "sg-Db")), group("Db")])
    config = AwsSecurityViz::AwsConfig.new(exclude: ["^Db$"])
    names = AwsSecurityViz::VisualizeAws.new(config).build.underlying.vertices
    expect(names).to eq(["sg-Web"])
  end

  def json_edges(groups, config)
    source = File.join(Dir.mktmpdir, "in.json")
    File.write(source, {"SecurityGroups" => groups}.to_json)
    edges = []
    recorder = Object.new
    recorder.define_singleton_method(:add_node) { |*| }
    recorder.define_singleton_method(:add_edge) { |from, to, opts| edges << [from, to, opts[:label]] }
    recorder.define_singleton_method(:output) {}
    AwsSecurityViz::VisualizeAws.new(config, source_file: source).build.output(recorder)
    edges
  end

  def sg(id, name, ingress, egress = [])
    {"GroupName" => name, "GroupId" => id, "VpcId" => "vpc-1", "IpPermissions" => ingress, "IpPermissionsEgress" => egress}
  end

  def pair_rule(pair)
    {"IpProtocol" => "tcp", "FromPort" => 22, "ToPort" => 22, "IpRanges" => [], "UserIdGroupPairs" => [pair]}
  end

  it "falls back to the group name when a group peer has no GroupId" do
    edges = json_edges([sg("sg-web", "web", [pair_rule("GroupName" => "legacy")])], AwsSecurityViz::AwsConfig.new)
    expect(edges).to eq([["legacy", "sg-web", "22/tcp"]])
  end

  it "collapses a self-referencing ingress and egress rule into one edge" do
    rule = pair_rule("GroupId" => "sg-web", "GroupName" => "web")
    edges = json_edges([sg("sg-web", "web", [rule], [rule])], AwsSecurityViz::AwsConfig.new(egress: true))
    expect(edges).to eq([["sg-web", "sg-web", "22/tcp"]])
  end

  # Re-keys the CLI JSON the way the SDK stub expects (snake_case symbols, ipv_6 spelling).
  def aws_shape(value)
    case value
    when Hash then value.to_h { |k, v| [k.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.sub("ipv6", "ipv_6").to_sym, aws_shape(v)] }
    when Array then value.map { |v| aws_shape(v) }
    else value
    end
  end
end
