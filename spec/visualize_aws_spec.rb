require 'spec_helper'

describe VisualizeAws do 
  before do
    @ec2 = mock(RightAws::Ec2)
    RightAws::Ec2.should_receive(:new).and_return(@ec2)
    @visualize_aws = VisualizeAws.new "key", "secret"
  end

  it "should add nodes for each security group" do
    @ec2.should_receive(:describe_security_groups).and_return(sample)
    graph = @visualize_aws.parse()
    node1 = graph.get_node('Remote ssh')
    node2 = graph.get_node('mymachine') 
    node1.should_not be_nil
    node2.should_not be_nil
    graph.each_edge.size.should == 1
    edge = graph.each_edge.first
    edge.node_one.should == GraphViz.escape(node2.id)
    edge.node_two.should == GraphViz.escape(node1.id)
  end

  def sample
    [
      {
        :aws_owner=>"aws-owner", :aws_group_name=>"Remote ssh", :aws_description=>"Ssh into remote box", :group_id=>"sg-111", 
        :aws_perms=>[{:from_port=>"22", :to_port=>"22", :protocol=>"tcp", :direction=>:ingress, :group_name=>"mymachine", :group_id=>"sg-123", :owner=>"own-123"}]
      },
      {
        :aws_owner=>"aws-owner", :aws_group_name=>"mymachine", :aws_description=>"my_machine", :group_id=>"sg-222", 
        :aws_perms=>[]
      }
    ]
  end
end
