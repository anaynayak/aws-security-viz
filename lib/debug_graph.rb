# frozen_string_literal: true

require "digest"
require_relative "graph"

class DebugGraph
  def initialize(config)
    @g = Graph.new(config, wildcard: h(PortLabel::ALL))
  end

  def add_node(name, opts)
    @g.add_node(h(name), hide_label(opts)) if name
  end

  def describe_node(key, opts)
    @g.describe_node(h(key), hide_label(opts))
  end

  def add_edge(from, to, opts)
    @g.add_edge(h(from), h(to), opts.merge(label: hide_tokens(opts[:label])))
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

  # Hash each comma-separated port token so that merged edges still deduplicate.
  def hide_tokens(label)
    label.to_s.split(",").map { |token| h(token) }.join(",")
  end

  def h(msg)
    Digest::SHA256.hexdigest msg
  end
end
