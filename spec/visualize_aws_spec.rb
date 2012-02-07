require 'spec_helper'

describe VisualizeAws do 
  before do
    @ec2 = mock(RightAws::Ec2)
    RightAws::Ec2.should_receive(:new).and_return(@ec2)
    @visualize_aws = VisualizeAws.new "key", "secret"
  end

  it "should add nodes for each security group" do
    @ec2.should_receive(:describe_security_groups).and_return([group('Remote ssh', ingress('22', 'My machine')), group('My machine')])
    graph = @visualize_aws.parse()
    node1 = graph.get_node('Remote ssh')
    node2 = graph.get_node('My machine') 
    node1.should_not be_nil
    node2.should_not be_nil
    graph.each_edge.size.should == 1
  end

  it "should add an edge for each security ingress" do
    @ec2.should_receive(:describe_security_groups).and_return([group('Remote ssh', ingress('22', 'My machine')), group('My machine')])
    graph = @visualize_aws.parse()
    graph.each_edge.size.should == 1
    graph.should have_edge "My machine" => 'Remote ssh'
  end

  it "should add nodes for external security groups defined through ingress" do
    @ec2.should_receive(:describe_security_groups).and_return([group('Web', ingress('80', 'ELB'))])
    graph = @visualize_aws.parse()
    graph.get_node('Web').should_not be_nil
    #graph.get_node('ELB').should_not be_nil
    graph.each_edge.size.should == 1
    graph.should have_edge("ELB" => 'Web')
  end

  it "should add an edge for each security ingress" do
    @ec2.should_receive(:describe_security_groups).and_return(
      [
        group('App', ingress('80', 'Web'), ingress('8983', 'Internal')), 
        group('Web', ingress('80', 'External')),
        group('Db', ingress('7474', 'App'))
    ])
    graph = @visualize_aws.parse()
    graph.each_edge.size.should == 4
    graph.should have_edge('Internal'=>'App', 'External' => 'Web', 'App'=> 'Db')
  end
end
