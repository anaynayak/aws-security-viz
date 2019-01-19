require_relative 'navigator'
require_relative 'json'
require_relative 'graphviz'
module Renderer
    ALL = {graphviz: Renderer::GraphViz, json: Renderer::Json, navigator: Renderer::Navigator}
    def self.pick(r, output_file, config)
        (ALL[(r || 'graphviz').to_sym]).new(output_file, config)
    end

    def self.copy_asset(asset, file_name)
        FileUtils.copy(File.expand_path("../../export/html/#{asset}", __FILE__),
        File.expand_path(asset, @file_name))
    end

    def self.all
        ALL.keys
    end
end