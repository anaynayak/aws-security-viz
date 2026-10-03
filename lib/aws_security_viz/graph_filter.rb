# frozen_string_literal: true

require_relative "directed_graph"

module AwsSecurityViz
  class GraphFilter
    def initialize(graph)
      @graph = graph
    end

    def filter(source, destination)
      return @graph if source.nil? && destination.nil?
      return @graph.induced(@graph.reachable_from(source)) if destination.nil?
      return @graph.induced(@graph.reverse.reachable_from(destination)) if source.nil?
      # Keep every vertex on some path source -> destination: reachable from the
      # source and able to reach the destination. Two searches, O(V+E).
      @graph.induced(@graph.reachable_from(source) & @graph.reverse.reachable_from(destination))
    end
  end
end
