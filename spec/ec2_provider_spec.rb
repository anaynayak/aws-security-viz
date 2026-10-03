# frozen_string_literal: true

require "spec_helper"
require "stringio"

describe AwsSecurityViz::Ec2Provider do
  def group(id)
    {group_id: id, group_name: id, vpc_id: "vpc-1", ip_permissions: [], ip_permissions_egress: []}
  end

  let(:client) { Aws::EC2::Client.new(stub_responses: true, region: "us-east-1") }

  it "reads every page" do
    client.stub_responses(:describe_security_groups, [
      {security_groups: [group("sg-1")], next_token: "t"},
      {security_groups: [group("sg-2")]}
    ])
    ids = AwsSecurityViz::Ec2Provider.new({}, client: client).security_groups.map(&:id)
    expect(ids).to eq(%w[sg-1 sg-2])
  end

  it "sends --vpc-id as a vpc-id filter" do
    seen = nil
    client.handle { |ctx|
      seen = ctx.params[:filters]
      @handler.call(ctx)
    }
    AwsSecurityViz::Ec2Provider.new({vpc_id: "vpc-1"}, client: client).security_groups
    expect(seen).to eq([{name: "vpc-id", values: ["vpc-1"]}])
  end

  describe "client options" do
    it "passes no region unless one is given, so the SDK chain decides" do
      allow(Aws::EC2::Client).to receive(:new).and_return(client)
      AwsSecurityViz::Ec2Provider.new({access_key: "a", secret_key: "b"}).security_groups
      expect(Aws::EC2::Client).to have_received(:new).with({access_key_id: "a", secret_access_key: "b"})
    end

    it "uses the named profile" do
      allow(Aws::EC2::Client).to receive(:new).and_return(client)
      AwsSecurityViz::Ec2Provider.new({profile: "dev", access_key: "a", secret_key: "b"}).security_groups
      expect(Aws::EC2::Client).to have_received(:new).with({profile: "dev"})
    end
  end
end

describe AwsSecurityViz::Ec2Provider, "multi-region" do
  def stub_client(original, region, id)
    original.call(stub_responses: {
      describe_security_groups: {security_groups: [{group_id: id, group_name: id, vpc_id: "vpc-#{region}"}]},
      describe_regions: {regions: [{region_name: "us-east-1"}, {region_name: "eu-west-1"}]}
    }, region: region)
  end

  before do
    allow(Aws::EC2::Client).to receive(:new).and_wrap_original { |original, opts|
      stub_client(original, opts[:region] || "us-east-1", "sg-#{opts[:region]}")
    }
  end

  it "queries each region in a comma-separated list and tags groups with their region" do
    groups = described_class.new({region: "eu-west-1, us-west-2"}).security_groups
    expect(groups.map { |g| [g.id, g.region] }).to eq([%w[sg-eu-west-1 eu-west-1], %w[sg-us-west-2 us-west-2]])
  end

  it "leaves the region unset for a single region" do
    expect(described_class.new({region: "eu-west-1"}).security_groups.map(&:region)).to eq([nil])
  end

  it "uses DescribeRegions for all_regions" do
    groups = described_class.new({all_regions: true}).security_groups
    expect(groups.map(&:region)).to eq(%w[eu-west-1 us-east-1])
  end

  it "uses -r as the bootstrap region for DescribeRegions with --all-regions" do
    described_class.new({all_regions: true, region: "ap-south-1"}).security_groups
    expect(Aws::EC2::Client).to have_received(:new).with(hash_including(region: "ap-south-1")).at_least(:once)
  end

  describe "failing regions" do
    def fail_region(bad_region, code)
      allow(Aws::EC2::Client).to receive(:new).and_wrap_original { |original, opts|
        region = opts[:region] || "us-east-1"
        c = stub_client(original, region, "sg-#{region}")
        c.stub_responses(:describe_security_groups, code) if bad_region.include?(region)
        c
      }
    end

    it "hashes the region in the skip warning when obfuscating" do
      fail_region(%w[eu-west-1], "AuthFailure")
      err = StringIO.new
      AwsSecurityViz.logger = AwsSecurityViz.build_logger(err)
      described_class.new({all_regions: true, obfuscate: true}).security_groups
      expect(err.string).to include("skipping region #{AwsSecurityViz::Obfuscation.hash("eu-west-1")}")
      expect(err.string).not_to include("eu-west-1")
    end

    it "warns and continues when a region is not enabled or not permitted" do
      %w[UnauthorizedOperation AuthFailure OptInRequired].each do |code|
        fail_region(%w[eu-west-1], code)
        err = StringIO.new
        AwsSecurityViz.logger = AwsSecurityViz.build_logger(err)
        groups = described_class.new({all_regions: true}).security_groups
        expect(groups.map(&:region)).to eq(%w[us-east-1])
        expect(err.string).to include("skipping region eu-west-1", code)
      end
    ensure
      AwsSecurityViz.logger = nil
    end

    it "raises when every region fails" do
      fail_region(%w[eu-west-1 us-east-1], "UnauthorizedOperation")
      AwsSecurityViz.logger = AwsSecurityViz.build_logger(StringIO.new)
      expect { described_class.new({all_regions: true}).security_groups }
        .to raise_error(Aws::EC2::Errors::UnauthorizedOperation)
    ensure
      AwsSecurityViz.logger = nil
    end

    it "does not swallow the error for a single region" do
      fail_region(%w[eu-west-1], "UnauthorizedOperation")
      expect { described_class.new({region: "eu-west-1"}).security_groups }
        .to raise_error(Aws::EC2::Errors::UnauthorizedOperation)
    end
  end
end
