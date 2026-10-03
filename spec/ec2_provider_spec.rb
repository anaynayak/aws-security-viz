# frozen_string_literal: true

require "spec_helper"

describe Ec2Provider do
  def group(id)
    {group_id: id, group_name: id, vpc_id: "vpc-1", ip_permissions: [], ip_permissions_egress: []}
  end

  let(:client) { Aws::EC2::Client.new(stub_responses: true, region: "us-east-1") }

  it "reads every page" do
    client.stub_responses(:describe_security_groups, [
      {security_groups: [group("sg-1")], next_token: "t"},
      {security_groups: [group("sg-2")]}
    ])
    ids = Ec2Provider.new({}, client: client).security_groups.map(&:group_id)
    expect(ids).to eq(%w[sg-1 sg-2])
  end

  it "sends --vpc-id as a vpc-id filter" do
    seen = nil
    client.handle { |ctx|
      seen = ctx.params[:filters]
      @handler.call(ctx)
    }
    Ec2Provider.new({vpc_id: "vpc-1"}, client: client).security_groups
    expect(seen).to eq([{name: "vpc-id", values: ["vpc-1"]}])
  end

  describe "client options" do
    it "passes no region unless one is given, so the SDK chain decides" do
      allow(Aws::EC2::Client).to receive(:new).and_return(client)
      Ec2Provider.new({access_key: "a", secret_key: "b"})
      expect(Aws::EC2::Client).to have_received(:new).with({access_key_id: "a", secret_access_key: "b"})
    end

    it "uses the named profile" do
      allow(Aws::EC2::Client).to receive(:new).and_return(client)
      Ec2Provider.new({profile: "dev", access_key: "a", secret_key: "b"})
      expect(Aws::EC2::Client).to have_received(:new).with({profile: "dev"})
    end
  end
end
