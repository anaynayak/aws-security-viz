require 'set'
require_relative 'ip_permission.rb'
require_relative 'groups.rb'

class SecurityGroups
  include Enumerable

  def initialize(provider)
    @groups = provider.security_groups
  end

  def each(&block)
    @groups.each { |group|
      if block_given?
        block.call SecurityGroup.new(@groups, group)
      else
        yield SecurityGroup.new(@groups, group)
      end
    }
  end
end

class SecurityGroup
  extend Forwardable

  def_delegator :@group, :name

  def initialize(all_groups, group)
    @all_groups = all_groups
    @group = group
  end

  def permissions
    ingress_permissions = @group.ip_permissions.collect { |ip|
      IpPermission.new(@group, ip, true)
    }
    egress_permissions = @group.ip_permissions_egress.collect { |ip|
      IpPermission.new(@group, ip, false)
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
    all = traffic.uniq.group_by {|t| [t.from, t.to, t.ingress]}.collect {|k,v| Traffic.grouped(v)}.uniq
    p all
  end

  private
  def mapping(val)
    group = @all_groups.find { |g| g.group_id == val }
    name = group.nil? ? val : group.name
    @user_groups[name] ? @user_groups[name] : name
  end
end