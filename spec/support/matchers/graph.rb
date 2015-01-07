RSpec::Matchers.define :have_edge do |edge|
  match do |actual|
    edges = actual.each_edge
    edge.each do |k,v|
      expect(edges.any? {|e| e.node_one == GraphViz.escape(k) && e.node_two == GraphViz.escape(v)}).to eq(true)
    end
  end
end
