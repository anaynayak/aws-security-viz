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
    @ip['ipProtocol'] == '-1' ? '*' : [@ip['fromPort'], @ip['toPort']].uniq.join('-')
  end

  def cidr_traffic
    @ip['ipRanges'].collect { |range|
      Traffic.new(@ingress, range['cidrIp'], @group.name, port_range)
    }
  end

  def group_traffic
    @ip['groups'].collect { |gp|
      groupName = gp['groupName'] || gp['groupId']
      Traffic.new(@ingress, groupName, @group.name, port_range)
    }
  end
end
