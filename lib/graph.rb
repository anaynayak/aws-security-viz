require 'rgl/adjacency'

class Graph
  attr_reader :underlying

  def initialize(config)
    @config = config
    @underlying = RGL::DirectedAdjacencyGraph.new
    @edge_properties = {}
  end

  def add_node(name)
    log("node: #{name}")
    @underlying.add_vertex(name)
  end

  def add_edge(from, to, opts)
    log("edge: #{from} -> #{to}")
    @underlying.add_edge(from, to)
    @edge_properties[[from, to]] = opts
  end

  def output(renderer)
    @underlying.each_vertex { |v| renderer.add_node(v) }
    @underlying.each_edge { |u, v|
      renderer.add_edge(u, v, opts(u, v))
    }
    renderer.output
  end

  def log(msg)
    puts msg if @config.debug?
  end

  private
  def opts(u, v)
    @edge_properties[[u, v]]
  end
end
