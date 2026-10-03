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
        category = opts[:region] ? "#{opts[:region]} / #{vpc}" : vpc
        label = opts[:label] || name
        info = "<b>Security group</b>: #{label}, <br/><b>VPC:</b> #{vpc}"
        info += "<br/><b>Region:</b> #{opts[:region]}" if opts[:region]
        @nodes << {id: name, label: label, categories: [category], info: info}.tap { |n| n[:region] = opts[:region] if opts[:region] }
        @categories.add(category)
      end

      def add_edge(from, to, opts)
        edge = {id: "#{from}-#{to}", from: from, to: to, label: opts[:label]}
        edge[:risky] = true if opts[:risky]
        @edges << edge
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
