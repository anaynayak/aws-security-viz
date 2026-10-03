# frozen_string_literal: true

require_relative "html"
require_relative "json"
require_relative "graphviz"
require_relative "mermaid"
module AwsSecurityViz
  module Renderer
    ALL = {graphviz: Renderer::GraphViz, json: Renderer::Json, html: Renderer::Html, mermaid: Renderer::Mermaid}
    DEFAULT = "html"
    EXTENSIONS = {
      "html" => :html, "htm" => :html, "json" => :json, "mmd" => :mermaid,
      "dot" => :graphviz, "gv" => :graphviz
    }.merge(GraphViz::IMAGE_EXTENSIONS.to_h { |e| [e, :graphviz] }) { |_, mine, _| mine }.freeze

    # Without an explicit renderer the output file's extension decides (see .infer).
    def self.pick(r, output_file, config)
      ALL.fetch(validate!(r || infer(output_file))).new(output_file, config)
    end

    # Renderer implied by the file extension; html when there is no file name. An unknown or missing extension
    # goes to graphviz, which rejects it with a message listing the usable extensions.
    def self.infer(file_name)
      return DEFAULT.to_sym if file_name.nil?
      EXTENSIONS.fetch(File.extname(file_name.to_s).delete_prefix(".").downcase, :graphviz)
    end

    # Returns the renderer as a symbol, or raises listing the valid choices.
    def self.validate!(r)
      name = (r || DEFAULT).to_s
      return name.to_sym if ALL.key?(name.to_sym)
      raise ArgumentError, "unknown renderer '#{name}' (choose from: #{all.join(", ")})"
    end

    # Default output file name: an image for graphviz, text for mermaid, JSON data for json, a page for html.
    def self.default_file(r)
      case validate!(r)
      when :graphviz then "aws-security-viz.png"
      when :mermaid then "aws-security-viz.#{Renderer::Mermaid::DEFAULT_EXTENSION}"
      when :json then "aws-security-viz.json"
      else "aws-security-viz.html"
      end
    end

    def self.all
      ALL.keys
    end
  end
end
