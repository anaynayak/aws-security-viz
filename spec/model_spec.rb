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

  # Re-keys the CLI JSON the way the SDK stub expects (snake_case symbols, ipv_6 spelling).
  def aws_shape(value)
    case value
    when Hash then value.to_h { |k, v| [k.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.sub("ipv6", "ipv_6").to_sym, aws_shape(v)] }
    when Array then value.map { |v| aws_shape(v) }
    else value
    end
  end
end
