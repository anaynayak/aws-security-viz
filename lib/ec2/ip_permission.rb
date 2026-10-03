# frozen_string_literal: true

require_relative "traffic"
require_relative "../port_label"

class IpPermission
  def initialize(group, ip, ingress, exclusions)
    @group = group
    @ip = ip
    @ingress = ingress
    @exclusions = exclusions
  end

  def traffic
    cidr_traffic + group_traffic
  end

  # Group id -> name for referenced groups whose name the provider reports.
  def peer_names
    @ip.groups.each_with_object({}) { |gp, names|
      names[gp.group_id] = gp.name if gp.group_id && gp.name != gp.group_id
    }
  end

  private

  def port_range
    PortLabel.format(@ip.protocol, @ip.from, @ip.to)
  end

  # IPv4 ranges, IPv6 ranges and prefix lists; each peer is named by its CIDR or prefix list id.
  def cidr_traffic
    (@ip.ip_ranges + @ip.ipv6_ranges + @ip.prefix_lists)
      .select { |range| !@exclusions.match(range) }
      .collect { |range|
      Traffic.new(@ingress, range.cidr_ip, @group.group_id, port_range)
    }
  end

  def group_traffic
    @ip.groups
      .select { |gp| !@exclusions.match(gp.name) }
      .collect { |gp|
      Traffic.new(@ingress, gp.group_id || gp.name, @group.group_id, port_range)
    }
  end
end
