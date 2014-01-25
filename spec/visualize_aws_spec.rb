require 'spec_helper'

describe VisualizeAws do
  before do
    @ec2 = double(Fog::Compute)
    Fog::Compute.should_receive(:new).and_return(@ec2)
  end

  let(:visualize_aws) {VisualizeAws.new}

  it 'should add nodes for each security group' do
    @ec2.should_receive(:security_groups).and_return([group('Remote ssh', group_ingress('22', 'My machine')), group('My machine')])
    graph = visualize_aws.build
    node1 = graph.get_node('Remote ssh')
    node2 = graph.get_node('My machine')
    node1.should_not be_nil
    node2.should_not be_nil
    graph.each_edge.size.should == 1
  end

  context 'groups' do
    it 'should add an edge for each security ingress' do
      @ec2.should_receive(:security_groups).and_return([group('Remote ssh', group_ingress('22', 'My machine')), group('My machine')])
      graph = visualize_aws.build
      graph.each_edge.size.should == 1
      graph.should have_edge "My machine" => 'Remote ssh'
    end

    it 'should add nodes for external security groups defined through ingress' do
      @ec2.should_receive(:security_groups).and_return([group('Web', group_ingress('80', 'ELB'))])
      graph = visualize_aws.build
      graph.get_node('Web').should_not be_nil
      #graph.get_node('ELB').should_not be_nil
      graph.each_edge.size.should == 1
      graph.should have_edge("ELB" => 'Web')
    end

    it 'should add an edge for each security ingress' do
      @ec2.should_receive(:security_groups).and_return(
        [
          group('App', group_ingress('80', 'Web'), group_ingress('8983', 'Internal')),
          group('Web', group_ingress('80', 'External')),
          group('Db', group_ingress('7474', 'App'))
      ])
      graph = visualize_aws.build
      graph.each_edge.size.should == 4
      graph.should have_edge('Internal'=>'App', 'External' => 'Web', 'App'=> 'Db')
    end
  end

  context 'cidr' do

    it 'should add an edge for each cidr ingress' do
      @ec2.should_receive(:security_groups).and_return(
        [
          group('Web', group_ingress('80', 'External')),
          group('Db', group_ingress('7474', 'App'), cidr_ingress('22', '127.0.0.1/32'))
      ])
      graph = visualize_aws.build
      graph.each_edge.size.should == 3
      graph.should have_edge('External' => 'Web', 'App'=> 'Db')
      graph.should have_edge('127.0.0.1/32' => 'Db' )
    end

    it 'should add map edges for cidr ingress' do
      @ec2.should_receive(:security_groups).and_return(
        [
          group('Web', group_ingress('80', 'External')),
          group('Db', group_ingress('7474', 'App'), cidr_ingress('22', '127.0.0.1/32'))
      ])
      mapping = {'127.0.0.1/32' => 'Work'}
      mapping = CidrGroupMapping.new([], mapping)
      CidrGroupMapping.stub(:new).and_return(mapping)

      graph = visualize_aws.build
      graph.each_edge.size.should == 3
      graph.should have_edge('External' => 'Web', 'App'=> 'Db')
      graph.should have_edge('Work' => 'Db' )
    end
    it 'should group mapped duplicate edges for cidr ingress' do
      @ec2.should_receive(:security_groups).and_return(
        [
          group('ssh', cidr_ingress('22', '192.168.0.1/32'), cidr_ingress('22', '127.0.0.1/32'))
      ])
      mapping = {'127.0.0.1/32' => 'Work', '192.168.0.1/32' => 'Work'}
      mapping = CidrGroupMapping.new([], mapping)
      CidrGroupMapping.stub(:new).and_return(mapping)

      graph = visualize_aws.build
      graph.each_edge.size.should == 1
      graph.should have_edge('Work' => 'ssh' )
    end
  end
end
