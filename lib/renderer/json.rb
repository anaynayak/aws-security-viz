module Renderer
  class Json
    def initialize(file_name, config)
      @nodes = []
      @edges = []
      @file_name = file_name
      @config = config
    end

    def add_node(name, opts)
      @nodes << {id: name, label: name}
    end

    def add_edge(from, to, opts)
      @edges << {id: "#{from}-#{to}", source: from, target: to, label: opts[:label]}
    end

    def output
      IO.write(@file_name, {nodes: @nodes, edges: @edges}.to_json)
      Renderer.copy_asset('view.html', @file_name)
    end
  end
end
