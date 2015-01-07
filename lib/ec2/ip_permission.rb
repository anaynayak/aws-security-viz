require_relative 'traffic.rb'

class IpPermission
  def initialize(group, ip, ingress)
    @group = group
    @ip = ip
    @ingress = ingress
  end

  def traffic
    cidr_traffic + group_traffic
  end

  private
  def port_range
    @ip.protocol == '-1' ? '*' : [@ip.from, @ip.to].uniq.join('-') + '/' + @ip.protocol
  end

  def cidr_traffic
    @ip.ip_ranges.collect { |range|
      Traffic.new(@ingress, range.cidr_ip, @group.name, port_range)
    }
  end

  def group_traffic
    @ip.groups.collect { |gp|
      Traffic.new(@ingress, gp.name, @group.name, port_range)
    }
  end
end
