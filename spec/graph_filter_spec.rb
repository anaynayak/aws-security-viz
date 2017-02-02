require 'spec_helper'
require 'ostruct'

describe GraphFilter do
  it 'should include nodes reachable from source' do
    graph = GraphFilter.new(RGL::DirectedAdjacencyGraph[1, 2, 2, 3, 2, 4, 4, 5])

    expect(graph.filter(2, nil).to_s).to eq('(2-3)(2-4)(4-5)')
  end
  it 'should remove nodes not reachable from source' do
    graph = GraphFilter.new(RGL::DirectedAdjacencyGraph[1, 2, 2, 3, 2, 4, 4, 5, 3, 5])

    expect(graph.filter(3, nil).to_s).to eq('(3-5)')
  end
  it 'should remove nodes not reachable to destination' do
    graph = GraphFilter.new(RGL::DirectedAdjacencyGraph[
                                1, 2,
                                1, 3,
                                1, 4,
                                2, 3,
                                2, 4,
                                3, 4,
                            ])

    expect(graph.filter(nil, 3).to_s).to eq('(1-2)(1-3)(2-3)')
  end
  it 'should remove nodes not reachable to destination from source' do
    graph = GraphFilter.new(RGL::DirectedAdjacencyGraph[
                                1, 2,
                                1, 3,
                                1, 4,
                                2, 3,
                                2, 4,
                            ])

    expect(graph.filter(2, 4).to_s).to eq('(2-4)')
  end
  it 'should retain edges which pass through intermediate nodes' do
    graph = GraphFilter.new(RGL::DirectedAdjacencyGraph[
                                1, 2,
                                1, 3,
                                1, 4,
                                2, 3,
                                2, 4,
                                3, 4,
                            ])
    expect(graph.filter(2, 4).to_s).to eq('(2-3)(2-4)(3-4)')
  end
  it 'should remove nodes not reachable to destination from source #1' do
    graph = GraphFilter.new(RGL::DirectedAdjacencyGraph[
                                1, 2,
                                1, 3,
                                1, 4,
                                2, 3,
                                2, 4,
                                3, 5,
                                5, 4
                            ])
    expect(graph.filter(1, 5).to_s).to eq('(1-2)(1-3)(2-3)(3-5)')
  end
  it 'should remove nodes not reachable to destination from source #2' do
    graph = GraphFilter.new(RGL::DirectedAdjacencyGraph[
                                1, 2,
                                1, 3,
                                1, 4,
                                2, 3,
                                2, 4,
                                3, 5,
                                5, 4
                            ])
    expect(graph.filter(1, 4).to_s).to eq('(1-2)(1-3)(1-4)(2-3)(2-4)(3-5)(5-4)')
  end
  it 'should remove nodes not reachable to destination from source #3' do
    graph = GraphFilter.new(RGL::DirectedAdjacencyGraph[
                                1, 2,
                                1, 3,
                                1, 4,
                                2, 3,
                                2, 4,
                                3, 5,
                                5, 4
                            ])
    expect(graph.filter(2, 4).to_s).to eq('(2-3)(2-4)(3-5)(5-4)')
  end
end
