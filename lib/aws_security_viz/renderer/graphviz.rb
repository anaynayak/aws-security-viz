# frozen_string_literal: true

require "open3"

module AwsSecurityViz
  module Renderer
    # Builds DOT text directly. `.dot`/`.gv` output is the text itself and needs no Graphviz;
    # any other extension is rendered by piping the text through `dot -T<ext> -K<layout>`.
    class GraphViz
      DOT_EXTENSIONS = %w[dot gv].freeze
      IMAGE_EXTENSIONS = %w[png svg pdf jpg jpeg gif webp bmp tiff ps eps json].freeze
      UNUSED_ATTRS = {style: "dashed,filled", fillcolor: "lightgrey", fontcolor: "gray30", tooltip: "Unused: no network interfaces attached"}.freeze
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
          node_attrs = {label: opts[:label] || name}
          node_attrs.merge!(UNUSED_ATTRS) if opts[:unused]
          line = "#{quote(name)} [#{attrs(node_attrs)}];"
          if opts[:vpc_id].nil? && opts[:region].nil?
            @root_nodes << line
          else
            (@clusters[[opts[:region], opts[:vpc_id]]] ||= []) << line
          end
          true
        end
      end

      def add_edge(from, to, opts)
        add_node(from, {})
        add_node(to, {})
        # Edges live in the root graph: an edge inside a cluster would pull its other endpoint in.
        edge_attrs = {style: "bold"}.merge(opts.except(:descriptions, :risky))
        edge_attrs = edge_attrs.merge(color: "crimson", style: "dashed", penwidth: 3) if opts[:risky]
        edge_attrs[:tooltip] = tooltip(opts[:descriptions]) unless opts[:descriptions].to_a.empty?
        @edges << "#{quote(from)} -> #{quote(to)} [#{attrs(edge_attrs)}];"
      end

      def to_dot
        lines = ["digraph \"G\" {"]
        lines << "  graph [#{attrs(GRAPH_ATTRS)}];"
        @clusters.group_by { |(region, _), _| region }.each do |region, entries|
          indent = region ? "    " : "  "
          body = entries.flat_map { |(_, vpc_id), node_lines| vpc_block(vpc_id, region, node_lines, indent) }
          lines.concat(region ? cluster(region, body) : body)
        end
        (@root_nodes + @edges).each { |l| lines << "  #{l}" }
        lines << "}"
        lines.join("\n") + "\n"
      end

      def output
        engine = @config.layout # validates the engine even when no image is rendered
        format = File.extname(@file_name.to_s).delete_prefix(".").downcase
        return File.write(@file_name, to_dot) if DOT_EXTENSIONS.include?(format)

        unless IMAGE_EXTENSIONS.include?(format)
          shown = format.empty? ? "no file extension" : "unknown file extension '.#{format}'"
          raise ArgumentError, "cannot pick an output format from #{@file_name.to_s.inspect}: #{shown} (supported: .html, .json, .mmd, .dot/.gv, or an image: #{(IMAGE_EXTENSIONS - %w[json]).map { |e| ".#{e}" }.join(", ")})"
        end
        raise ArgumentError, "Graphviz 'dot' not found; install graphviz" unless on_path?("dot")
        image, err, status = Open3.capture3("dot", "-T#{format}", "-K#{engine}", stdin_data: to_dot, binmode: true)
        raise ArgumentError, "Graphviz failed: #{err.strip}" unless status.success?
        File.binwrite(@file_name, image)
      end

      private

      # Nodes of one VPC (or loose nodes of a region without a VPC), indented.
      def vpc_block(vpc_id, region, node_lines, indent)
        return node_lines.map { |l| "#{indent}#{l}" } unless vpc_id
        id = region ? "cluster_#{region}/#{vpc_id}" : "cluster_#{vpc_id}"
        ["#{indent}subgraph #{quote(id)} {", "#{indent}  label=#{quote(vpc_id)};"] +
          node_lines.map { |l| "#{indent}  #{l}" } + ["#{indent}}"]
      end

      # One line per rule description, prefixed by its ports; quote() escapes the free text.
      def tooltip(descriptions)
        descriptions.map { |d| "#{d[:ports]}: #{d[:text]}" }.join("\n")
      end

      def cluster(region, body)
        ["  subgraph #{quote("cluster_#{region}")} {", "    label=#{quote(region)};"] + body + ["  }"]
      end

      # Quotes an ID or label for DOT: backslash and double quote are escaped, newlines become \n.
      # A backslash is escaped too, so a literal "\N" in data cannot be read as a Graphviz escape.
      def quote(value)
        escaped = value.to_s.gsub("\\") { "\\\\" }.gsub('"') { '\\"' }.gsub(/\r\n|\r|\n/) { "\\n" }
        "\"#{escaped}\""
      end

      def attrs(opts)
        opts.map { |k, v| "#{k}=#{quote(v)}" }.join(", ")
      end

      def on_path?(command)
        pathext = ENV.fetch("PATHEXT", "").split(File::PATH_SEPARATOR).reject(&:empty?)
        # PATHEXT is upper case (.EXE) but the file is usually dot.exe; only Windows matches case-insensitively.
        suffixes = [""] + pathext.flat_map { |ext| [ext, ext.downcase] }.uniq
        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir|
          suffixes.any? { |suffix|
            path = File.join(dir, command + suffix)
            File.file?(path) && File.executable?(path)
          }
        }
      end
    end
  end
end
