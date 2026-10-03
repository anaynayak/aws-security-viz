# frozen_string_literal: true

require "rgl/adjacency"

class Graph
  attr_reader :underlying

  def initialize(config, underlying = RGL::DirectedAdjacencyGraph.new)
    @config = config
    @underlying = underlying
    @edge_properties = {}
    @node_properties = {}
  end

  def add_node(name, opts)
    log("node: #{name}, opts: #{opts}")
    @underlying.add_vertex(name)
    @node_properties[name] = opts
  end

  # Labels a node that only appears as an edge endpoint (e.g. a group outside the
  # described set); a node already added with properties is left alone.
  def describe_node(key, opts)
    @node_properties[key] ||= opts if @underlying.has_vertex?(key)
  end

  def add_edge(from, to, opts)
    log("edge: #{from} -> #{to}")
    @underlying.add_edge(from, to)
    @edge_properties[[from, to]] = merge_edge(@edge_properties[[from, to]], opts)
  end

  def filter(source, destination)
    @underlying = GraphFilter.new(underlying).filter(resolve(source), resolve(destination))
  end

  def output(renderer)
    @underlying.each_vertex { |v| renderer.add_node(v, @node_properties[v] || {}) }
    @underlying.each_edge { |u, v|
      renderer.add_edge(u, v, opts(u, v))
    }
    renderer.output
  end

  def log(msg)
    puts msg if @config.debug?
  end

  private

  # A filter may be a group id (a node key) or a group name (a node label).
  def resolve(filter)
    return filter if filter.nil? || @underlying.has_vertex?(filter)
    keys = @underlying.vertices.select { |v| @node_properties.dig(v, :label) == filter }
    raise ArgumentError, "'#{filter}' matches several groups (#{keys.join(", ")}); use a group id" if keys.size > 1
    keys.first || filter
  end

  # Rules from several groups (or egress and ingress) can map to one edge: keep the
  # first colour and union the port labels in a stable order.
  def merge_edge(existing, opts)
    return opts unless existing
    labels = [existing[:label], opts[:label]].compact.flat_map { |l| l.split(",") }
    existing.merge(label: labels.uniq.sort.join(","))
  end

  def opts(u, v)
    @edge_properties[[u, v]]
  end
end
