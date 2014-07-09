require 'graphviz'
require 'logger'

class Graph
  def initialize
    @g = GraphViz::new('G')
  end

  def add_node(name)
    log("node: #{name}")
    @g.add_node(name)
  end

  def add_edge(from, to, opts)
    log("edge: #{from} -> #{to}")
    @g.add_edge(from, to, opts)
  end

  def output(opts)
    log("output: #{opts}")
    @g.output(opts)
  end

  def log(msg)
    puts msg if ENV["DEBUG"]
  end
end
