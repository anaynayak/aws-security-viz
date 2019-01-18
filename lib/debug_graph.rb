require 'digest'
require_relative 'graph'

class DebugGraph
  def initialize(config)
    @g = Graph.new(config)
  end

  def add_node(name, opts)
    @g.add_node(h(name), opts) if name
  end

  def add_edge(from, to, opts)
    @g.add_edge(h(from), h(to), opts.update(label: h(opts[:label])))
  end

  def filter(source, destination)
    @g.filter(source, destination)
  end

  def output(renderer)
    @g.output(renderer)
  end

  private
  def h(msg)
    Digest::SHA256.hexdigest msg
  end
end
