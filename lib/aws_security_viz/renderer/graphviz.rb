# frozen_string_literal: true

require "graphviz"

module Renderer
  class GraphViz
    def initialize(file_name, config)
      @g = Graphviz::Graph.new("G", overlap: false,
        splines: true,
        sep: 1,
        concentrate: true,
        rankdir: "LR")
      @file_name = file_name
      @config = config
      @nodes = {}
      @clusters = {}
    end

    def add_node(name, opts)
      @nodes[name] ||= parent_for(opts[:vpc_id]).add_node(name, label: opts[:label] || name)
    end

    def add_edge(from, to, opts)
      from_node = add_node(from, {})
      to_node = add_node(to, {})
      options = {style: "bold"}.merge(opts)
      # Edges live in the root graph: an edge inside a cluster would pull its other endpoint in.
      Graphviz::Edge.new(@g, from_node, to_node, options)
    end

    def output
      engine = @config.layout
      raise ArgumentError, "Graphviz '#{engine}' not found; install graphviz" unless on_path?(engine)
      # format: nil to force detection based on extension; the layout engine is the executable.
      Graphviz.output(@g, path: @file_name, format: nil, dot: @config.layout)
    end

    private

    def on_path?(command)
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir|
        path = File.join(dir, command)
        File.file?(path) && File.executable?(path)
      }
    end

    def parent_for(vpc_id)
      return @g if vpc_id.nil?
      @clusters[vpc_id] ||= @g.add_subgraph(vpc_id, cluster: true, label: vpc_id)
    end
  end
end
