require 'set'
require 'forwardable'
require_relative 'ip_permission.rb'

class SecurityGroups
  include Enumerable

  def initialize(provider, config)
    @groups = provider.security_groups
    @config = config
  end

  def each(&block)
    groups = @groups.select { |sg| !@config.exclusions.match(sg.name) }
    groups.each { |group|
      if block_given?
        block.call SecurityGroup.new(@groups, group, @config)
      else
        yield SecurityGroup.new(@groups, group, @config)
      end
    }
  end

  def size
    @groups.size
  end
end

class SecurityGroup
  extend Forwardable

  def_delegators :@group, :name, :vpc_id, :group_id

  def initialize(all_groups, group, config)
    @all_groups = all_groups
    @group = group
    @config = config
  end

  def permissions
    ingress_permissions = @group.ip_permissions.collect { |ip|
      IpPermission.new(@group, ip, true, @config.exclusions)
    }
    return ingress_permissions unless @config.egress?
    egress_permissions = @group.ip_permissions_egress.collect { |ip|
      IpPermission.new(@group, ip, false, @config.exclusions)
    }
    ingress_permissions + egress_permissions
  end

  def traffic
    all_traffic = permissions.collect { |permission|
      permission.traffic
    }.flatten.uniq
    CidrGroupMapping.new(@all_groups, @config.groups).map(all_traffic)
  end
end

class CidrGroupMapping
  def initialize(all_groups, user_groups)
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
