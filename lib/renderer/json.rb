module Renderer
  class Json
    def initialize(file_name, config)
      @nodes = []
      @edges = []
      @file_name = file_name
      @config = config
    end

    def add_node(name)
      @nodes << {id: name, label: name}
    end

    def add_edge(from, to, opts)
      @edges << {id: "#{from}-#{to}", source: from, target: to}
    end

    def output
      IO.write(@file_name, {nodes: @nodes, edges: @edges}.to_json)
    end

  end
end