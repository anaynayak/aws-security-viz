# frozen_string_literal: true

require_relative "navigator"
require_relative "json"
require_relative "graphviz"
require_relative "mermaid"
module AwsSecurityViz
  module Renderer
    ALL = {graphviz: Renderer::GraphViz, json: Renderer::Json, navigator: Renderer::Navigator, mermaid: Renderer::Mermaid}
    DEFAULT = "graphviz"

    def self.pick(r, output_file, config)
      ALL.fetch(validate!(r)).new(output_file, config)
    end

    # Returns the renderer as a symbol, or raises listing the valid choices.
    def self.validate!(r)
      name = (r || DEFAULT).to_s
      return name.to_sym if ALL.key?(name.to_sym)
      raise ArgumentError, "unknown renderer '#{name}' (choose from: #{all.join(", ")})"
    end

    # Default output file name: an image for graphviz, text for mermaid, JSON data for the viewer renderers.
    def self.default_file(r)
      case validate!(r)
      when :graphviz then "aws-security-viz.png"
      when :mermaid then "aws-security-viz.#{Renderer::Mermaid::DEFAULT_EXTENSION}"
      else "aws-security-viz.json"
      end
    end

    def self.copy_asset(asset, file_name)
      FileUtils.copy(File.expand_path("../../export/html/#{asset}", __FILE__),
        File.join(File.dirname(File.expand_path(file_name)), asset))
    end

    def self.all
      ALL.keys
    end
  end
end
