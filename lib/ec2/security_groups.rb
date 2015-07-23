require 'set'
require 'forwardable'
require_relative 'ip_permission.rb'
require_relative 'groups.rb'

class SecurityGroups
  include Enumerable

  def initialize(provider, exclusions)
    @groups = provider.security_groups
    @exclusions = exclusions
  end

  def each(&block)
    groups = @groups.select { |sg| !@exclusions.match(sg.name) }
    groups.each { |group|
      if block_given?
        block.call SecurityGroup.new(@groups, group, @exclusions)
      else
        yield SecurityGroup.new(@groups, group, @exclusions)
      end
    }
  end

  def size
    @groups.size
  end
end

class SecurityGroup
  extend Forwardable

  def_delegator :@group, :name

  def initialize(all_groups, group, exclusions)
    @all_groups = all_groups
    @group = group
    @exclusions = exclusions
  end

  def permissions
    ingress_permissions = @group.ip_permissions.collect { |ip|
      IpPermission.new(@group, ip, true, @exclusions)
    }
    egress_permissions = @group.ip_permissions_egress.collect { |ip|
      IpPermission.new(@group, ip, false, @exclusions)
    }
    ingress_permissions + egress_permissions
  end

  def traffic
    all_traffic = permissions.collect { |permission|
      permission.traffic
    }.flatten.uniq
    CidrGroupMapping.new(@all_groups).map(all_traffic)
  end
end

class CidrGroupMapping
  def initialize(all_groups, user_groups = USER_GROUPS)
    @all_groups = all_groups
    @user_groups = user_groups
  end

  def map(all_traffic)
    traffic = all_traffic.collect { |traffic|
      traffic.copy(mapping(traffic.from), mapping(traffic.to))
    }
    traffic.uniq.group_by {|t| [t.from, t.to, t.ingress]}.collect {|k,v| Traffic.grouped(v)}.uniq
  end

  private
  def mapping(val)
    group = @all_groups.find { |g| g.group_id == val }
    name = group.nil? ? val : group.name
    @user_groups[name] ? @user_groups[name] : name
  end
end
