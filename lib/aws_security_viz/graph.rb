# frozen_string_literal: true

require_relative "directed_graph"
require_relative "port_label"
require_relative "obfuscation"
require_relative "logging"

module AwsSecurityViz
  class Graph
    attr_reader :underlying

    def initialize(config, underlying = DirectedGraph.new)
      @config = config
      @underlying = underlying
      @edge_properties = {}
      @node_properties = {}
    end

    def add_node(name, opts)
      log("node: #{loggable(name)}, opts: #{@config.obfuscate? ? Obfuscation.node_opts(opts) : opts}")
      @underlying.add_vertex(name)
      @node_properties[name] = opts
    end

    # Labels a node that only appears as an edge endpoint (e.g. a group outside the
    # described set); a node already added with properties is left alone.
    def describe_node(key, opts)
      @node_properties[key] ||= opts if @underlying.has_vertex?(key)
    end

    def add_edge(from, to, opts)
      log("edge: #{loggable(from)} -> #{loggable(to)}")
      @underlying.add_edge(from, to)
      @edge_properties[[from, to]] = merge_edge(@edge_properties[[from, to]], opts)
    end

    def filter(source, destination)
      @underlying = GraphFilter.new(underlying).filter(resolve(source), resolve(destination))
    end

    def output(renderer)
      nodes = @underlying.vertices.map { |v| [v, @node_properties[v] || {}] }
      edges = @underlying.edges.map { |e| [e.source, e.target, opts(e.source, e.target)] }
      nodes, edges = Obfuscation.apply(nodes, edges) if @config.obfuscate?
      nodes.each { |v, node_opts| renderer.add_node(v, node_opts) }
      edges.each { |u, v, edge_opts| renderer.add_edge(u, v, edge_opts) }
      renderer.output
    end

    def log(msg)
      AwsSecurityViz.logger.debug(msg) if @config.debug?
    end

    private

    # Debug output is what users paste into bug reports, so it is hashed like the rest.
    def loggable(value)
      @config.obfuscate? ? Obfuscation.hash(value) : value
    end

    # A filter may be a group id (a node key) or a group name (a node label).
    def resolve(filter)
      return filter if filter.nil? || @underlying.has_vertex?(filter)
      keys = @underlying.vertices.select { |v| @node_properties.dig(v, :label) == filter }
      raise ArgumentError, "no group or peer matches '#{filter}'" if keys.empty?
      if keys.size > 1
        raise ArgumentError, "'#{filter}' matches several groups (#{keys.map { |k| loggable(k) }.join(", ")}); use a group id"
      end
      keys.first
    end

    # Rules from several groups (or egress and ingress) can map to one edge: union the
    # port labels and pick the colour independently of rule order (ingress blue wins
    # over egress red).
    def merge_edge(existing, opts)
      return opts unless existing
      color = [existing[:color], opts[:color]].include?(:blue) ? :blue : opts[:color]
      merged = existing.merge(opts).merge(color: color, label: PortLabel.normalise("#{existing[:label]},#{opts[:label]}"))
      descriptions = (existing[:descriptions].to_a + opts[:descriptions].to_a).uniq
      descriptions.empty? ? merged : merged.merge(descriptions: descriptions)
    end

    def opts(u, v)
      @edge_properties[[u, v]]
    end
  end
end
