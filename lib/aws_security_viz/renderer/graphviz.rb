# frozen_string_literal: true

require "open3"

module AwsSecurityViz
  module Renderer
    # Builds DOT text directly. `.dot`/`.gv` output is the text itself and needs no Graphviz;
    # any other extension is rendered by piping the text through `dot -T<ext> -K<layout>`.
    class GraphViz
      DOT_EXTENSIONS = %w[dot gv].freeze
      GRAPH_ATTRS = {overlap: false, splines: true, sep: 1, concentrate: true, rankdir: "LR"}.freeze

      def initialize(file_name, config)
        @file_name = file_name
        @config = config
        @nodes = {}
        @clusters = {}
        @root_nodes = []
        @edges = []
      end

      def add_node(name, opts)
        @nodes[name] ||= begin
          line = "#{quote(name)} [#{attrs(label: opts[:label] || name)}];"
          if opts[:vpc_id].nil?
            @root_nodes << line
          else
            (@clusters[opts[:vpc_id]] ||= []) << line
          end
          true
        end
      end

      def add_edge(from, to, opts)
        add_node(from, {})
        add_node(to, {})
        # Edges live in the root graph: an edge inside a cluster would pull its other endpoint in.
        @edges << "#{quote(from)} -> #{quote(to)} [#{attrs({style: "bold"}.merge(opts))}];"
      end

      def to_dot
        lines = ["digraph \"G\" {"]
        lines << "  graph [#{attrs(GRAPH_ATTRS)}];"
        @clusters.each do |vpc_id, node_lines|
          lines << "  subgraph #{quote("cluster_#{vpc_id}")} {"
          lines << "    label=#{quote(vpc_id)};"
          node_lines.each { |l| lines << "    #{l}" }
          lines << "  }"
        end
        (@root_nodes + @edges).each { |l| lines << "  #{l}" }
        lines << "}"
        lines.join("\n") + "\n"
      end

      def output
        engine = @config.layout # validates the engine even when no image is rendered
        format = File.extname(@file_name.to_s).delete_prefix(".").downcase
        return File.write(@file_name, to_dot) if DOT_EXTENSIONS.include?(format)

        raise ArgumentError, "Graphviz 'dot' not found; install graphviz" unless on_path?("dot")
        image, err, status = Open3.capture3("dot", "-T#{format}", "-K#{engine}", stdin_data: to_dot, binmode: true)
        raise ArgumentError, "Graphviz failed: #{err.strip}" unless status.success?
        File.binwrite(@file_name, image)
      end

      private

      # Quotes an ID or label for DOT: backslash and double quote are escaped, newlines become \n.
      # A backslash is escaped too, so a literal "\N" in data cannot be read as a Graphviz escape.
      def quote(value)
        escaped = value.to_s.gsub("\\") { "\\\\" }.gsub('"') { '\\"' }.gsub(/\r?\n/) { "\\n" }
        "\"#{escaped}\""
      end

      def attrs(opts)
        opts.map { |k, v| "#{k}=#{quote(v)}" }.join(", ")
      end

      def on_path?(command)
        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir|
          path = File.join(dir, command)
          File.file?(path) && File.executable?(path)
        }
      end
    end
  end
end
