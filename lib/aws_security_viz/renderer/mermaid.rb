# frozen_string_literal: true

module AwsSecurityViz
  module Renderer
    # Writes a Mermaid flowchart (.mmd). Node and subgraph ids are generated (n0, g0, ...) so no
    # data can break the syntax; names, ports and VPC/region titles only appear as quoted labels.
    # Rule descriptions have no Mermaid equivalent (no tooltips) and are left out.
    class Mermaid
      DEFAULT_EXTENSION = "mmd"
      RISKY_STYLE = "stroke:#dc143c,stroke-width:4px,stroke-dasharray:6 3"
      EDGE_STYLES = {blue: "stroke:#1f5fbf", red: "stroke:#c0392b"}.freeze

      def initialize(file_name, config)
        @file_name = file_name
        @config = config
        @ids = {}
        @labels = {}
        @groups = {}
        @edges = []
      end

      def add_node(name, opts)
        id = node_id(name)
        return if @labels.key?(id)
        @labels[id] = opts[:label] || name
        (@groups[[opts[:region], opts[:vpc_id]]] ||= []) << id if opts[:vpc_id] || opts[:region]
      end

      def add_edge(from, to, opts)
        add_node(from, {})
        add_node(to, {})
        @edges << [node_id(from), node_id(to), opts]
      end

      def to_mermaid
        lines = ["flowchart LR"]
        grouped = @groups.values.flatten
        sequence = 0
        @groups.group_by { |(region, _), _| region }.each do |region, entries|
          indent = region ? "    " : "  "
          lines << "  subgraph g#{sequence += 1}[#{quote(region)}]" if region
          entries.each do |(_, vpc_id), ids|
            if vpc_id
              lines << "#{indent}subgraph g#{sequence += 1}[#{quote(vpc_id)}]"
              ids.each { |id| lines << "#{indent}  #{node(id)}" }
              lines << "#{indent}end"
            else
              ids.each { |id| lines << "#{indent}#{node(id)}" }
            end
          end
          lines << "  end" if region
        end
        (@labels.keys - grouped).each { |id| lines << "  #{node(id)}" }
        @edges.each { |from, to, opts| lines << "  #{from} #{arrow(opts)} #{to}" }
        @edges.each_with_index do |(_, _, opts), index|
          style = opts[:risky] ? RISKY_STYLE : EDGE_STYLES[opts[:color]]
          lines << "  linkStyle #{index} #{style}" if style
        end
        lines.join("\n") + "\n"
      end

      def output
        File.write(@file_name, to_mermaid)
      end

      private

      def node_id(name)
        @ids[name] ||= "n#{@ids.size}"
      end

      def node(id)
        "#{id}[#{quote(@labels[id])}]"
      end

      def arrow(opts)
        label = opts[:label].to_s
        label.empty? ? "-->" : "-->|#{quote(label)}|"
      end

      # Mermaid quoted text takes HTML-style entity codes; '#' goes first so it never re-escapes.
      def quote(value)
        escaped = value.to_s.gsub("#", "#35;").gsub('"', "#quot;").gsub("<", "#lt;").gsub(">", "#gt;")
          .gsub("`", "#96;").gsub(/\r\n|\r|\n/, " ")
        "\"#{escaped}\""
      end
    end
  end
end
