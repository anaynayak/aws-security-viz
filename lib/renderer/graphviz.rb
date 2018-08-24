require 'graphviz'

module Renderer
  class GraphViz
    def initialize(file_name, config)
      @g = ::GraphViz::new('G', :type => 'strict digraph') { |g|
        g[:overlap] = :false
        g[:splines] = :true
        g[:sep] = 1
        g[:concentrate] = :true
        g[:rankdir] = "LR"
      }
      @file_name = file_name
      @config = config
    end

    def add_node(name)
      @g.add_node(name)
    end

    def add_edge(from, to, opts)
      @g.add_edge(from, to, ({style: 'bold'}).merge(opts))
    end

    def output
      extension = File.extname(@file_name)
      opts = {extension[1..-1].to_sym => @file_name, :use => @config.format}
      @g.output(opts)
    end
  end
end
