# frozen_string_literal: true

require "digest"
require_relative "graph"

class DebugGraph
  def initialize(config)
    @g = Graph.new(config)
  end

  def add_node(name, opts)
    @g.add_node(h(name), hide_label(opts)) if name
  end

  def describe_node(key, opts)
    @g.describe_node(h(key), hide_label(opts))
  end

  def add_edge(from, to, opts)
    @g.add_edge(h(from), h(to), opts.update(label: h(opts[:label])))
  end

  def filter(source, destination)
    @g.filter(source && h(source), destination && h(destination))
  end

  def output(renderer)
    @g.output(renderer)
  end

  private

  def hide_label(opts)
    opts.key?(:label) ? opts.merge(label: h(opts[:label])) : opts
  end

  def h(msg)
    Digest::SHA256.hexdigest msg
  end
end
