class Graph
  attr_reader :ops

  def initialize(config)
    @config = config
    @ops = []
  end

  def add_node(name)
    log("node: #{name}")
    @ops << [:node, name] if name
  end

  def add_edge(from, to, opts)
    log("edge: #{from} -> #{to}")
    @ops << [:edge, from, to, opts]
  end

  def output(renderer)
    @ops.each { |op, *args|
      renderer.add_node(*args) if op==:node
      renderer.add_edge(*args) if op==:edge
    }
    renderer.output
  end

  def log(msg)
    puts msg if ENV["DEBUG"]
  end
end
