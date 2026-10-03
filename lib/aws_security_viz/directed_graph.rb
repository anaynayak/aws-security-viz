# frozen_string_literal: true

module AwsSecurityViz
  # A small directed graph kept as insertion-ordered adjacency lists.
  class DirectedGraph
    Edge = Data.define(:source, :target) do
      def to_s = "(#{source}-#{target})"
    end

    # DirectedGraph[1, 2, 2, 3] builds the edges 1->2 and 2->3.
    def self.[](*pairs)
      new.tap { |g| pairs.each_slice(2) { |u, v| g.add_edge(u, v) } }
    end

    def initialize
      @adjacency = {}
    end

    def add_vertex(v)
      @adjacency[v] ||= Set.new
      self
    end

    def add_edge(u, v)
      add_vertex(u)
      add_vertex(v)
      @adjacency[u] << v
      self
    end

    def has_vertex?(v) = @adjacency.key?(v)

    def vertices = @adjacency.keys

    def edges
      @adjacency.flat_map { |u, targets| targets.map { |v| Edge.new(u, v) } }
    end

    def reverse
      each_edge_into(self.class.new) { |g, u, v| g.add_edge(v, u) }
    end

    # Vertices reachable from +start+ (including it), by breadth-first search.
    def reachable_from(start)
      return Set.new unless has_vertex?(start)
      seen = Set[start]
      queue = [start]
      until queue.empty?
        @adjacency[queue.shift].each { |v| queue << v if seen.add?(v) }
      end
      seen
    end

    # The subgraph on +keep+ and the edges between its vertices.
    def induced(keep)
      sub = self.class.new
      @adjacency.each_key { |v| sub.add_vertex(v) if keep.include?(v) }
      @adjacency.each { |u, ts| ts.each { |v| sub.add_edge(u, v) if keep.include?(u) && keep.include?(v) } }
      sub
    end

    def to_s = edges.map(&:to_s).sort.join

    private

    def each_edge_into(target)
      vertices.each { |v| target.add_vertex(v) }
      edges.each { |e| yield target, e.source, e.target }
      target
    end
  end
end
