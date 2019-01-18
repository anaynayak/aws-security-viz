require 'spec_helper'

class DummyRenderer
  attr_reader :output

  def initialize
    @output = []
  end

  def add_node(name, opts)
    @output << [:node, name]
  end

  def add_edge(from, to, opts)
    @output << [:edge, from, to, opts]
  end
end

describe VisualizeAws do
  let(:visualize_aws) { VisualizeAws.new(AwsConfig.new) }
  let(:renderer) { DummyRenderer.new }

  it 'should add nodes, edges for each security group' do   
    stub_security_groups([group('Remote ssh', group_ingress(22, 'My machine')), group('My machine')])
    graph = visualize_aws.build

    expect(graph.output(renderer)).to contain_exactly(
                                          [:node, 'Remote ssh'],
                                          [:node, 'My machine'],
                                          [:edge, 'My machine', 'Remote ssh', {:color => :blue, :label => '22/tcp'}],
                                      )
  end

  context 'groups' do
    it 'should add nodes for external security groups defined through ingress' do
      stub_security_groups([group('Web', group_ingress(80, 'ELB'))])
      graph = visualize_aws.build

      expect(graph.output(renderer)).to contain_exactly(
                                            [:node, 'Web'],
                                            [:node, 'ELB'],
                                            [:edge, 'ELB', 'Web', {:color => :blue, :label => '80/tcp'}]
                                        )
    end

    it 'should add an edge for each security ingress' do
      stub_security_groups(
          [
              group('App', group_ingress(80, 'Web'), group_ingress(8983, 'Internal')),
              group('Web', group_ingress(80, 'External')),
              group('Db', group_ingress(7474, 'App'))
          ])
      graph = visualize_aws.build

      expect(graph.output(renderer)).to contain_exactly(
                                            [:node, 'App'],
                                            [:node, 'Web'],
                                            [:edge, 'Web', 'App', {:color => :blue, :label => '80/tcp'}],
                                            [:node, 'Internal'],
                                            [:edge, 'Internal', 'App', {:color => :blue, :label => '8983/tcp'}],
                                            [:node, 'External'],
                                            [:edge, 'External', 'Web', {:color => :blue, :label => '80/tcp'}],
                                            [:node, 'Db'],
                                            [:edge, 'App', 'Db', {:color => :blue, :label => '7474/tcp'}]
                                        )

    end
  end

  context 'cidr' do

    it 'should add an edge for each cidr ingress' do
        stub_security_groups(
          [
              group('Web', group_ingress(80, 'External')),
              group('Db', group_ingress(7474, 'App'), cidr_ingress(22, '127.0.0.1/32'))
          ])
      graph = visualize_aws.build

      expect(graph.output(renderer)).to contain_exactly(
                                            [:node, 'Web'],
                                            [:node, 'External'],
                                            [:edge, 'External', 'Web', {:color => :blue, :label => '80/tcp'}],
                                            [:node, 'Db'],
                                            [:node, 'App'],
                                            [:edge, 'App', 'Db', {:color => :blue, :label => '7474/tcp'}],
                                            [:node, '127.0.0.1/32'],
                                            [:edge, '127.0.0.1/32', 'Db', {:color => :blue, :label => '22/tcp'}]
                                        )

    end

    it 'should add map edges for cidr ingress' do
        stub_security_groups(
          [
              group('Web', group_ingress(80, 'External')),
              group('Db', group_ingress(7474, 'App'), cidr_ingress(22, '127.0.0.1/32'))
          ])
      mapping = {'127.0.0.1/32' => 'Work'}
      mapping = CidrGroupMapping.new([], mapping)
      allow(CidrGroupMapping).to receive(:new).and_return(mapping)

      graph = visualize_aws.build

      expect(graph.output(renderer)).to contain_exactly(
                                            [:node, 'Web'],
                                            [:node, 'External'],
                                            [:edge, 'External', 'Web', {:color => :blue, :label => '80/tcp'}],
                                            [:node, 'Db'],
                                            [:node, 'App'],
                                            [:edge, 'App', 'Db', {:color => :blue, :label => '7474/tcp'}],
                                            [:node, 'Work'],
                                            [:edge, 'Work', 'Db', {:color => :blue, :label => '22/tcp'}]
                                        )

    end

    it 'should group mapped duplicate edges for cidr ingress' do
    stub_security_groups(
          [
              group('ssh', cidr_ingress(22, '192.168.0.1/32'), cidr_ingress(22, '127.0.0.1/32'))
          ])
      mapping = {'127.0.0.1/32' => 'Work', '192.168.0.1/32' => 'Work'}
      mapping = CidrGroupMapping.new([], mapping)
      allow(CidrGroupMapping).to receive(:new).and_return(mapping)

      graph = visualize_aws.build

      expect(graph.output(renderer)).to contain_exactly(
                                            [:node, 'ssh'],
                                            [:node, 'Work'],
                                            [:edge, 'Work', 'ssh', {:color => :blue, :label => '22/tcp'}]
                                        )
    end
  end

  context "filter" do
    it 'include cidr which do not match the pattern' do
        stub_security_groups(
          [
              group('Web', cidr_ingress(22, '127.0.0.1/32')),
              group('Db', cidr_ingress(22, '192.0.1.1/32'))
          ])

      opts = {:exclude => ['127.*']}
      graph = VisualizeAws.new(AwsConfig.new(opts)).build

      expect(graph.output(renderer)).to contain_exactly(
                                            [:node, 'Web'],
                                            [:node, 'Db'],
                                            [:node, '192.0.1.1/32'],
                                            [:edge, '192.0.1.1/32', 'Db', {:color => :blue, :label => '22/tcp'}]
                                        )
    end

    it 'include groups which do not match the pattern' do
        stub_security_groups(
          [
              group('Web', group_ingress(80, 'External')),
              group('Db', group_ingress(7474, 'App'), cidr_ingress(22, '127.0.0.1/32'))
          ])

      opts = {:exclude => ['D.*b', 'App']}
      graph = VisualizeAws.new(AwsConfig.new(opts)).build

      expect(graph.output(renderer)).to contain_exactly(
                                            [:node, 'Web'],
                                            [:node, 'External'],
                                            [:edge, 'External', 'Web', {:color => :blue, :label => '80/tcp'}]
                                        )
    end

    it 'include derived groups which do not match the pattern' do
        stub_security_groups(
          [
              group('Web', group_ingress(80, 'External')),
              group('Db', group_ingress(7474, 'App'), cidr_ingress(22, '127.0.0.1/32'))
          ])

      opts = {:exclude => ['App']}
      graph = VisualizeAws.new(AwsConfig.new(opts)).build

      expect(graph.output(renderer)).to contain_exactly(
                                            [:node, 'Web'],
                                            [:node, 'External'],
                                            [:edge, 'External', 'Web', {:color => :blue, :label => '80/tcp'}],
                                            [:node, 'Db'],
                                            [:node, '127.0.0.1/32'],
                                            [:edge, '127.0.0.1/32', 'Db', {:color => :blue, :label => '22/tcp'}]
                                        )

    end
  end
end
