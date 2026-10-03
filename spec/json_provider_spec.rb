# frozen_string_literal: true

require "spec_helper"

describe AwsSecurityViz::JsonProvider do
  let(:fixture) { File.expand_path("fixtures/graph_bugs.json", __dir__) }

  it "reads every group without --vpc-id" do
    expect(AwsSecurityViz::JsonProvider.new(source_file: fixture).security_groups.map(&:vpc_id).uniq).to contain_exactly("vpc-a", "vpc-b")
  end

  it "keeps only groups of the --vpc-id" do
    groups = AwsSecurityViz::JsonProvider.new(source_file: fixture, vpc_id: "vpc-b").security_groups
    expect(groups.map(&:vpc_id).uniq).to eq(["vpc-b"])
  end
end
