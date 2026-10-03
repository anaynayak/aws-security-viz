# frozen_string_literal: true

module AwsSecurityViz
  module Renderer
    class Navigator
      def initialize(file_name, config)
        @nodes = []
        @edges = []
        @file_name = file_name
        @config = config
        @categories = Set.new
      end

      def add_node(name, opts)
        vpc = opts[:vpc_id] || "default"
        label = opts[:label] || name
        info = "<b>Security group</b>: #{label}, <br/><b>VPC:</b> #{vpc}"
        @nodes << {id: name, label: label, categories: [vpc], info: info}
        @categories.add(vpc)
      end

      def add_edge(from, to, opts)
        @edges << {id: "#{from}-#{to}", from: from, to: to, label: opts[:label]}
      end

      def output
        IO.write(@file_name, {
          data: {nodes: @nodes, edges: @edges},
          categories: @categories.to_h { |c| [c, c] }
        }.to_json)
        Renderer.copy_asset("navigator.html", @file_name)
      end
    end
  end
end
