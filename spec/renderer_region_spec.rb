# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"

describe "region in viewer outputs" do
  def render(klass, nodes, obfuscate: false)
    Dir.mktmpdir { |dir|
      file = File.join(dir, "out.json")
      config = AwsSecurityViz::AwsConfig.new(obfuscate: obfuscate)
      graph = AwsSecurityViz::Graph.new(config)
      nodes.each { |id, opts| graph.add_node(id, opts) }
      graph.output(klass.new(file, config))
      JSON.parse(File.read(file))
    }
  end

  let(:nodes) { [["sg-1", {label: "a", vpc_id: "vpc-1", region: "eu-west-1"}], ["sg-2", {label: "b", vpc_id: "vpc-1"}]] }

  it "adds a region field to json nodes when set" do
    json = render(AwsSecurityViz::Renderer::Json, nodes)
    expect(json["nodes"].map { |n| n["region"] }).to eq(["eu-west-1", nil])
  end

  it "hashes the region under obfuscation" do
    expect(render(AwsSecurityViz::Renderer::Json, nodes, obfuscate: true).to_json).not_to include("eu-west-1")
  end
end
