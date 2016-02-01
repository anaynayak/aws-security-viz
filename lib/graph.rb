class Graph
  attr_reader :ops

  def initialize(config)
    @config = config
    @ops = []
    @nodes = Set.new
  end

  def add_node(name)
    log("node: #{name}")
    uniquely_add(@ops, :node, name) {
      [:node, name]
    }
  end

  def add_edge(from, to, opts)
    log("edge: #{from} -> #{to}")
    add_node(from)
    add_node(to)
    uniquely_add(@ops, :edge, from, to) {
      [:edge, from, to, opts]
    }
  end

  def output(renderer)
    @ops.each { |op, *args|
      renderer.add_node(*args) if op==:node
      renderer.add_edge(*args) if op==:edge
    }
    renderer.output
  end

  def uniquely_add(target, type, *opts, &block)
    return if opts.compact.empty?
    return if @nodes.include?([type, opts])
    @nodes.add([type, opts])
    target << yield
  end


  def log(msg)
    puts msg if @config.debug?
  end
end
