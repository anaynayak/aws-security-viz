module Renderer
    class Navigator
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
        @edges << {id: "#{from}-#{to}", from: from, to: to, label: opts[:label]}
      end
  
      def output
        IO.write(@file_name, {data: {nodes: @nodes, edges: @edges}}.to_json)
        Renderer.copy_asset('navigator.html', @file_name)
      end
    end
  end
  