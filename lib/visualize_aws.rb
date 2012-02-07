require 'right_aws'
require 'graphviz'
require File.join(File.dirname(__FILE__), 'groups.rb')

require 'set'

class VisualizeAws
  def initialize(access_key, secret_key)
    @ec2 = RightAws::Ec2.new(access_key, secret_key)
  end

  def parse
    groups = @ec2.describe_security_groups
    g = GraphViz::new( "G" )
    nodes = groups.collect {|group| group[:aws_group_name]}
    nodes.each {|n| g.add_node(n)}
    GroupIngress.new(groups).each {|from, to, port_range| g.add_edge( from, to, :color => "blue", :style => "bold", :label => port_range )}
    CidrIngress.new(groups, CidrGroupMapping.new).each {|from, to, port_range| g.add_edge( from, to, :color => "green", :style => "bold", :label => port_range )}
    g
  end

  def unleash
    g = parse
    g.output( :png => "aws-security-viz.png" )
  end

  class GroupIngress
    def initialize(groups)
      @groups = groups
    end
    def each
      @groups.each do |group|
        group[:aws_perms].each do |perm|
          yield perm[:group_name], group[:aws_group_name], [perm[:from_port], perm[:to_port]].uniq.join("-")  if perm[:group_name]
        end
      end
    end
  end

  class CidrIngress
    def initialize(groups, filter)
      @groups = groups
      @filter = filter
    end

    def each
      @groups.each do |group|
        group[:aws_perms].each do |perm|
          next if not perm[:cidr_ips] 
          args = [perm[:cidr_ips], group[:aws_group_name], [perm[:from_port], perm[:to_port]].uniq.join("-")]
          @filter.map(args) { |mapped_args| yield mapped_args}
        end
      end
    end
  end

  class CidrGroupMapping 
    def initialize
      @seen = Set.new
    end
    def map args, &block
      mapped_args = [mapping(args[0])] + args[1..-1]
      return if @seen.include? mapped_args 
      @seen.add(args)
      block.call(mapped_args)
    end 
    def mapping(val)
      USER_GROUPS[val]? USER_GROUPS[val] : val
    end
  end
end

if __FILE__ == $0
  access_key = ARGV[0]
  secret_key = ARGV[1]
  VisualizeAws.new(access_key, secret_key).unleash
end
