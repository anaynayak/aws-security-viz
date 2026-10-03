# frozen_string_literal: true

require "spec_helper"

describe AwsSecurityViz::GraphFilter do
  it "should include nodes reachable from source" do
    graph = AwsSecurityViz::GraphFilter.new(AwsSecurityViz::DirectedGraph[1, 2, 2, 3, 2, 4, 4, 5])

    expect(graph.filter(2, nil).to_s).to eq("(2-3)(2-4)(4-5)")
  end
  it "should remove nodes not reachable from source" do
    graph = AwsSecurityViz::GraphFilter.new(AwsSecurityViz::DirectedGraph[1, 2, 2, 3, 2, 4, 4, 5, 3, 5])

    expect(graph.filter(3, nil).to_s).to eq("(3-5)")
  end
  it "should remove nodes not reachable to destination" do
    graph = AwsSecurityViz::GraphFilter.new(AwsSecurityViz::DirectedGraph[
      1, 2,
      1, 3,
      1, 4,
      2, 3,
      2, 4,
      3, 4
                            ])

    expect(graph.filter(nil, 3).to_s).to eq("(1-2)(1-3)(2-3)")
  end
  it "should remove nodes not reachable to destination from source" do
    graph = AwsSecurityViz::GraphFilter.new(AwsSecurityViz::DirectedGraph[
      1, 2,
      1, 3,
      1, 4,
      2, 3,
      2, 4
                            ])

    expect(graph.filter(2, 4).to_s).to eq("(2-4)")
  end
  it "should retain edges which pass through intermediate nodes" do
    graph = AwsSecurityViz::GraphFilter.new(AwsSecurityViz::DirectedGraph[
      1, 2,
      1, 3,
      1, 4,
      2, 3,
      2, 4,
      3, 4
                            ])
    expect(graph.filter(2, 4).to_s).to eq("(2-3)(2-4)(3-4)")
  end
  it "should remove nodes not reachable to destination from source #1" do
    graph = AwsSecurityViz::GraphFilter.new(AwsSecurityViz::DirectedGraph[
      1, 2,
      1, 3,
      1, 4,
      2, 3,
      2, 4,
      3, 5,
      5, 4
                            ])
    expect(graph.filter(1, 5).to_s).to eq("(1-2)(1-3)(2-3)(3-5)")
  end
  it "should remove nodes not reachable to destination from source #2" do
    graph = AwsSecurityViz::GraphFilter.new(AwsSecurityViz::DirectedGraph[
      1, 2,
      1, 3,
      1, 4,
      2, 3,
      2, 4,
      3, 5,
      5, 4
                            ])
    expect(graph.filter(1, 4).to_s).to eq("(1-2)(1-3)(1-4)(2-3)(2-4)(3-5)(5-4)")
  end
  it "should remove nodes not reachable to destination from source #3" do
    graph = AwsSecurityViz::GraphFilter.new(AwsSecurityViz::DirectedGraph[
      1, 2,
      1, 3,
      1, 4,
      2, 3,
      2, 4,
      3, 5,
      5, 4
                            ])
    expect(graph.filter(2, 4).to_s).to eq("(2-3)(2-4)(3-5)(5-4)")
  end
end

describe AwsSecurityViz::GraphFilter, "on a dense graph" do
  it "filters source+target in linear time (path enumeration would never finish)" do
    graph = AwsSecurityViz::DirectedGraph.new
    (0...40).each { |i| (i + 1...40).each { |j| graph.add_edge(i, j) } }
    filtered = Timeout.timeout(5) { AwsSecurityViz::GraphFilter.new(graph).filter(0, 39) }

    expect(filtered.vertices.size).to eq(40)
  end
  it "returns an empty graph when the destination is unreachable" do
    graph = AwsSecurityViz::DirectedGraph[1, 2, 3, 4]

    expect(AwsSecurityViz::GraphFilter.new(graph).filter(1, 4).vertices).to be_empty
  end
end
