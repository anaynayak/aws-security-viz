# frozen_string_literal: true

module AwsSecurityViz
  module Renderer
    class Json
      def initialize(file_name, config)
        @nodes = []
        @edges = []
        @file_name = file_name
        @config = config
      end

      def add_node(name, opts)
        @nodes << {id: name, label: opts[:label] || name, region: opts[:region], unused: (true if opts[:unused])}.compact
      end

      def add_edge(from, to, opts)
        edge = {id: "#{from}-#{to}", source: from, target: to, label: opts[:label]}
        edge[:descriptions] = opts[:descriptions] if opts[:descriptions]
        edge[:risky] = true if opts[:risky]
        @edges << edge
      end

      def output
        File.write(@file_name, {nodes: @nodes, edges: @edges}.to_json)
      end
    end
  end
end
