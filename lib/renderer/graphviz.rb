require 'graphviz'

module Renderer
  class GraphViz
    def initialize(file_name, config)
      @g = Graphviz::Graph.new('G', {
        overlap: false,
        splines: true,
        sep: 1,
        concentrate: true,
        rankdir: "LR"
      })
      @file_name = file_name
      @config = config
    end

    def add_node(name, opts)
      @g.add_node(name, label: name)
    end

    def add_edge(from, to, opts)
      from_node = create_if_missing(from)
      to_node = create_if_missing(to)
      options =  ({style: 'bold'}).merge(opts)
      from_node.connect(to_node, options)
    end

    def create_if_missing(name)
      n = @g.get_node(name).first
      n.nil? ? add_node(name, {}) : n
    end
    
    def output
      Graphviz::output(@g, path: @file_name, format: nil) #format: nil to force detection based on extension.
    end
  end
end
