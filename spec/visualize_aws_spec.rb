require 'spec_helper'

describe VisualizeAws do
  before do
    @ec2 = double(Fog::Compute)
    allow(Fog::Compute).to receive(:new).and_return(@ec2)
  end

  let(:visualize_aws) {VisualizeAws.new(AwsConfig.new)}

  it 'should add nodes for each security group' do
    expect(@ec2).to receive(:security_groups).and_return([group('Remote ssh', group_ingress('22', 'My machine')), group('My machine')])
    graph = visualize_aws.build
    node1 = graph.get_node('Remote ssh')
    node2 = graph.get_node('My machine')

    expect(node1).not_to be_nil
    expect(node2).not_to be_nil
    expect(graph.each_edge.size).to eq(1)
  end

  context 'groups' do
    it 'should add an edge for each security ingress' do
      expect(@ec2).to receive(:security_groups).and_return([group('Remote ssh', group_ingress('22', 'My machine')), group('My machine')])
      graph = visualize_aws.build

      expect(graph.each_edge.size).to eq(1)
      expect(graph).to have_edge "My machine" => 'Remote ssh'
    end

    it 'should add nodes for external security groups defined through ingress' do
      expect(@ec2).to receive(:security_groups).and_return([group('Web', group_ingress('80', 'ELB'))])
      graph = visualize_aws.build

      expect(graph.get_node('Web')).to_not be_nil
      expect(graph.get_node('ELB')).to_not be_nil
      expect(graph.each_edge.size).to eq(1)
      expect(graph).to have_edge("ELB" => 'Web')
    end

    it 'should add an edge for each security ingress' do
      expect(@ec2).to receive(:security_groups).and_return(
        [
          group('App', group_ingress('80', 'Web'), group_ingress('8983', 'Internal')),
          group('Web', group_ingress('80', 'External')),
          group('Db', group_ingress('7474', 'App'))
      ])
      graph = visualize_aws.build

      expect(graph.each_edge.size).to eq(4)
      expect(graph).to have_edge('Internal'=>'App', 'External' => 'Web', 'App'=> 'Db')
    end
  end

  context 'cidr' do

    it 'should add an edge for each cidr ingress' do
      expect(@ec2).to receive(:security_groups).and_return(
        [
          group('Web', group_ingress('80', 'External')),
          group('Db', group_ingress('7474', 'App'), cidr_ingress('22', '127.0.0.1/32'))
      ])
      graph = visualize_aws.build

      expect(graph.each_edge.size).to eq(3)
      expect(graph).to have_edge('External' => 'Web', 'App'=> 'Db')
      expect(graph).to have_edge('127.0.0.1/32' => 'Db' )
    end

    it 'should add map edges for cidr ingress' do
      expect(@ec2).to receive(:security_groups).and_return(
        [
          group('Web', group_ingress('80', 'External')),
          group('Db', group_ingress('7474', 'App'), cidr_ingress('22', '127.0.0.1/32'))
      ])
      mapping = {'127.0.0.1/32' => 'Work'}
      mapping = CidrGroupMapping.new([], mapping)
      allow(CidrGroupMapping).to receive(:new).and_return(mapping)

      graph = visualize_aws.build

      expect(graph.each_edge.size).to eq(3)
      expect(graph).to have_edge('External' => 'Web', 'App'=> 'Db')
      expect(graph).to have_edge('Work' => 'Db' )
    end
    it 'should group mapped duplicate edges for cidr ingress' do
      expect(@ec2).to receive(:security_groups).and_return(
        [
          group('ssh', cidr_ingress('22', '192.168.0.1/32'), cidr_ingress('22', '127.0.0.1/32'))
      ])
      mapping = {'127.0.0.1/32' => 'Work', '192.168.0.1/32' => 'Work'}
      mapping = CidrGroupMapping.new([], mapping)
      allow(CidrGroupMapping).to receive(:new).and_return(mapping)

      graph = visualize_aws.build

      expect(graph.each_edge.size).to eq(1)
      expect(graph).to have_edge('Work' => 'ssh' )
    end
  end
  context "filter" do
    it 'include groups which do not match the pattern' do
      expect(@ec2).to receive(:security_groups).and_return(
        [
          group('Web', group_ingress('80', 'External')),
          group('Db', group_ingress('7474', 'App'), cidr_ingress('22', '127.0.0.1/32'))
      ])

      opts = {:exclude => ['D.*b', 'App']}
      graph = VisualizeAws.new(AwsConfig.new(opts)).build

      expect(graph.each_edge.size).to eq(1)
      expect(graph).to have_edge('External' => 'Web')
    end

    it 'include derived groups which do not match the pattern' do
      expect(@ec2).to receive(:security_groups).and_return(
        [
          group('Web', group_ingress('80', 'External')),
          group('Db', group_ingress('7474', 'App'), cidr_ingress('22', '127.0.0.1/32'))
      ])

      opts = {:exclude => ['App']}
      graph = VisualizeAws.new(AwsConfig.new(opts)).build

      expect(graph.each_edge.size).to eq(2)
      expect(graph).to have_edge('External' => 'Web')
      expect(graph).to have_edge('127.0.0.1/32' => 'Db' )
    end

  end
end
