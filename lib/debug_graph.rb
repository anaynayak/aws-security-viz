require 'digest'
require_relative 'graph'

class DebugGraph
  def initialize(config)
    @g = Graph.new(config)
  end

  def add_node(name)
    @g.add_node(h(name)) if name
  end

  def add_edge(from, to, opts)
    @g.add_edge(h(from), h(to), opts.update(label: h(opts[:label])))
  end

  def output(renderer)
    @g.output(renderer)
  end

  private
  def h(msg)
    Digest::SHA256.hexdigest msg
  end
end
