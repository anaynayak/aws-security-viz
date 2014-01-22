require 'fog'
require 'graphviz'
require_relative 'groups.rb'
require 'set'

class VisualizeAws
  def initialize(access_key, secret_key)
    @compute = Fog::Compute.new(:provider => 'AWS', :aws_access_key_id => access_key, :aws_secret_access_key => secret_key)
  end

  def parse
    groups = @compute.security_groups
    g = GraphViz::new( "G" )
    nodes = groups.collect {|group| group.name}
    nodes.each {|n| g.add_node(n)}
    GroupIngress.new(groups).each {|from, to, port_range| g.add_edge( from, to, :color => "blue", :style => "bold", :label => port_range )}
    CidrIngress.new(groups, CidrGroupMapping.new).each {|from, to, port_range| g.add_edge( from, to, :color => "green", :style => "bold", :label => port_range )}
    g
  end

  def unleash(output_file)
    g = parse
    extension = File.extname(output_file)
    g.output( extension[1..-1].to_sym => output_file )
  end

  class GroupIngress
    def initialize(groups)
      @groups = groups
    end
    def each
      @groups.each do |group|
        group.ip_permissions.each do |perm|
          perm["groups"].each { |gp|
            yield gp["groupName"], group.name, [perm["fromPort"], perm["toPort"]].uniq.join("-")
          }
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
        group.ip_permissions.each do |perm|
          perm["ipRanges"].each { |ip|
            args = [ip["cidrIp"], group.name, [perm["fromPort"], perm["toPort"]].uniq.join("-")]
            @filter.map(args) { |mapped_args| yield mapped_args}
          }
        end
      end
    end
  end

  class CidrGroupMapping 
    def initialize user_groups = USER_GROUPS
      @seen = Set.new
      @user_groups = user_groups
    end
    def map args, &block
      mapped_args = [mapping(args[0])] + args[1..-1]
      return if @seen.include? mapped_args 
      @seen.add(mapped_args)
      block.call(mapped_args)
    end 
    def mapping(val)
      @user_groups[val]? @user_groups[val] : val
    end
  end
end

if __FILE__ == $0
  access_key = ARGV[0]
  secret_key = ARGV[1]
  output_file = ARGV[2] || "aws-security-viz.png"
  VisualizeAws.new(access_key, secret_key).unleash(output_file)
end
