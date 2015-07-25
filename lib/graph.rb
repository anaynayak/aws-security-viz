require 'graphviz'
require 'logger'

class Graph
  def initialize
    @g = GraphViz::new('G', :type => 'strict digraph') { |g|
      g[:overlap] = :false
      g[:splines] = :true
      g[:sep] = 1
      g[:concentrate] = :true
    }
  end

  def add_node(name)
    log("node: #{name}")
    @g.add_node(name) if name
  end

  def get_node(name, &block)
    @g.get_node(name, &block)
  end

  def add_edge(from, to, opts)
    log("edge: #{from} -> #{to}")
    @g.add_edge(from, to, opts)
  end

  def each_edge(&block)
    @g.each_edge(&block)
  end

  def output(opts)
    log("output: #{opts}")
    @g.output(opts)
  end

  def log(msg)
    puts msg if ENV["DEBUG"]
  end
end
