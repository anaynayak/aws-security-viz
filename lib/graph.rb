require 'rgl/adjacency'

class Graph
  attr_reader :underlying

  def initialize(config, underlying=RGL::DirectedAdjacencyGraph.new)
    @config = config
    @underlying = underlying
    @edge_properties = {}
    @node_properties = {}
  end

  def add_node(name, opts)
    log("node: #{name}, opts: #{opts}")
    @underlying.add_vertex(name)
    @node_properties[name] = opts
  end

  def add_edge(from, to, opts)
    log("edge: #{from} -> #{to}")
    @underlying.add_edge(from, to)
    @edge_properties[[from, to]] = opts
  end

  def filter(source, destination)
    @underlying = GraphFilter.new(underlying).filter(source, destination)
  end

  def output(renderer)
    @underlying.each_vertex { |v| renderer.add_node(v, @node_properties[v] || {}) }
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
