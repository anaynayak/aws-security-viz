require_relative '../graph.rb'
require 'organic_hash'

@oh = OrganicHash.new

def h(s)
  @oh.hash(s)
end


def debug
  g = Graph.new
  File.readlines('debug-output.log').map do |l| 
    type, left, right = l.split(/\W+/)
    if type=="node"
      g.add_node(h(left), {})
    elsif type=="edge"
      g.add_edge(h(left), h(right), {})
    end
  end
  g.output(:svg => 'test.svg', :use => 'sfdp')
end

if __FILE__ == $0
  debug
end
