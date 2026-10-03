# frozen_string_literal: true

require_relative "navigator"
require_relative "json"
require_relative "graphviz"
module Renderer
  ALL = {graphviz: Renderer::GraphViz, json: Renderer::Json, navigator: Renderer::Navigator}
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

  # Default output file name: an image for graphviz, JSON data for the viewer renderers.
  def self.default_file(r)
    (validate!(r) == :graphviz) ? "aws-security-viz.png" : "aws-security-viz.json"
  end

  def self.copy_asset(asset, file_name)
    FileUtils.copy(File.expand_path("../../export/html/#{asset}", __FILE__),
      File.join(File.dirname(File.expand_path(file_name)), asset))
  end

  def self.all
    ALL.keys
  end
end
