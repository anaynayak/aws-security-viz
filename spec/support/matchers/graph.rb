Rspec::Matchers.define :have_edge do |edge|
  match do |actual|
    edges = actual.each_edge
    edge.each do |k,v|
      edges.any? {|e| e.node_one == GraphViz.escape(k) && e.node_two == GraphViz.escape(v)}.should == true
    end
  end
end
