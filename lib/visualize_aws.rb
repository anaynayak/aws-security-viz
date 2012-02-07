require 'right_aws'
require 'graphviz'
require './groups'
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
    identify_group_ingress(groups) {|from, to, port_range| g.add_edge( from, to, :color => "blue", :style => "bold", :label => port_range )}
    identify_cidr_ingress(groups) {|from, to, port_range| g.add_edge( from, to, :color => "green", :style => "bold", :label => port_range )}
    g
  end

  def unleash
    g = parse
    g.output( :png => "aws-security-viz.png" )
  end

  def identify_group_ingress(groups)
    groups.each do |group|
      group[:aws_perms].each do |perm|
        yield perm[:group_name], group[:aws_group_name], [perm[:from_port], perm[:to_port]].uniq.join("-")  if perm[:group_name]
      end
    end
  end

  def mapping(val)
    USER_GROUPS[val]? USER_GROUPS[val] : val
  end

  def identify_cidr_ingress(groups)
    seen = Set.new
    groups.each do |group|
      group[:aws_perms].each do |perm|
        next if not perm[:cidr_ips] 
        args = [mapping(perm[:cidr_ips]), group[:aws_group_name], [perm[:from_port], perm[:to_port]].uniq.join("-")]
        yield args if not seen.include?(args)
        seen.add(args)
      end
    end
  end

end

if __FILE__ == $0
  access_key = ARGV[0]
  secret_key = ARGV[1]
  VisualizeAws.new(access_key, secret_key).unleash
end
