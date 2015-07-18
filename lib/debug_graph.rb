require 'digest'

class DebugGraph
  def initialize
    @g = Graph.new
  end

  def add_node(name)
    @g.add_node(h(name)) if name
  end

  def add_edge(from, to, opts)
    @g.add_edge(h(from), h(to), opts.update(label: h(opts[:label])))
  end

  def output(opts)
    @g.output(opts)
  end

  private
  def h(msg)
    Digest::SHA256.hexdigest msg
  end
end
