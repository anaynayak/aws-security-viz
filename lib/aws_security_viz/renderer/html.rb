# frozen_string_literal: true

require "json"

module AwsSecurityViz
  module Renderer
    # Writes one self-contained .html file: the vendored Cytoscape.js and the graph data are inlined, so it
    # opens from file:// with no network access. Data only reaches the page as JSON (see viewer.html, which
    # builds the DOM with textContent), never as markup.
    class Html
      TEMPLATE = File.expand_path("../export/html/viewer.html", __dir__)
      VENDOR = File.expand_path("../vendor", __dir__)
      CYTOSCAPE = File.join(VENDOR, "cytoscape/cytoscape.min.js")
      # Load order matters: fcose needs cose-base, which needs layout-base.
      LIBRARIES = {
        "CYTOSCAPE" => CYTOSCAPE,
        "LAYOUT_BASE" => File.join(VENDOR, "layout-base/layout-base.js"),
        "COSE_BASE" => File.join(VENDOR, "cose-base/cose-base.js"),
        "FCOSE" => File.join(VENDOR, "fcose/cytoscape-fcose.js")
      }.freeze

      def initialize(file_name, config)
        @file_name = file_name
        @config = config
        @nodes = []
        @edges = []
      end

      def add_node(name, opts)
        @nodes << {id: name, label: opts[:label] || name, vpc: opts[:vpc_id], region: opts[:region], unused: (true if opts[:unused]), rules: opts[:rules]}.compact
      end

      def add_edge(from, to, opts)
        edge = {id: "#{from}-#{to}", source: from, target: to, label: opts[:label], kind: (opts[:color] == :red) ? "egress" : "ingress"}
        edge[:descriptions] = opts[:descriptions] if opts[:descriptions]
        edge[:risky] = true if opts[:risky]
        @edges << edge
      end

      def output
        parts = LIBRARIES.to_h { |name, path| ["/*#{name}*/", File.read(path)] }
        parts["/*DATA*/"] = json_for_script({nodes: @nodes, edges: @edges})
        # One pass, so no inlined part can be mistaken for another's placeholder.
        File.write(@file_name, File.read(TEMPLATE).gsub(%r{/\*(?:#{[*LIBRARIES.keys, "DATA"].join("|")})\*/}) { |marker| parts.fetch(marker) })
      end

      private

      # "<" is escaped so no value can close the script element or open a comment.
      def json_for_script(data)
        data.to_json.gsub("<", "\\u003c")
      end
    end
  end
end
