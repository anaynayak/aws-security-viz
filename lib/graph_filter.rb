require 'rgl/traversal'
require 'rgl/implicit'

class GraphFilter
  def initialize(graph)
    @graph = graph
  end

  def filter(source, destination)
    return @graph if source.nil? && destination.nil?
    if !source.nil? && destination.nil?
      return reduce(@graph, source)
    end
    if !destination.nil? && source.nil?
      return reduce(@graph.reverse, destination).reverse
    end
    search(@graph, source, destination)
  end

  private
  def reduce(graph, source)
    tree = graph.bfs_search_tree_from(source)
    graph.vertices_filtered_by { |v| tree.has_vertex? v }
  end

  def search(graph, source, destination)
    visitor = RGL::DFSVisitor.new(graph)
    path = []
    paths = []
    visitor.set_examine_vertex_event_handler { |x| path << x }
    visitor.set_finish_vertex_event_handler { |x| path.pop }
    visitor.set_examine_edge_event_handler { |x, y| paths << path.clone + [y] if y == destination }
    graph.depth_first_visit(source, visitor) { |x|}
    to_remove = graph.vertices - paths.flatten
    graph.remove_vertices(*to_remove)
    graph
  end
end
