require 'fog/aws'

class Ec2Provider

  def initialize(options)
    conn_opts = {
      region: options[:region]
    }

    conn_opts[:aws_access_key_id] = options[:access_key]
    conn_opts[:aws_secret_access_key] = options[:secret_key]

    @compute = Fog::Compute::AWS.new conn_opts
  end

  def security_groups
    @compute.security_groups.collect { |sg|
      Ec2::SecurityGroup.new(sg)
    }
  end
end

module Ec2
  class SecurityGroup
    extend Forwardable
    def_delegators :@sg, :name, :group_id
    def initialize(sg)
      @sg = sg
    end

    def ip_permissions
      @sg.ip_permissions.collect { |ip|
        Ec2::IpPermission.new(ip)
      }
    end

    def ip_permissions_egress
      @sg.ip_permissions_egress.collect { |ip|
        Ec2::IpPermission.new(ip)
      }
    end
  end

  class IpPermission
    def initialize(ip)
      @ip = ip
    end

    def protocol
      @ip['ipProtocol']
    end

    def from
      @ip['fromPort']
    end

    def to
      @ip['toPort']
    end

    def ip_ranges
      @ip['ipRanges'].collect {|gp|
        Ec2::IpPermissionRange.new(gp)
      }
    end

    def groups
      @ip['groups'].collect {|gp|
        Ec2::IpPermissionGroup.new(gp)
      }
    end
  end

  class IpPermissionRange
    def initialize(range)
      @range = range
    end

    def cidr_ip
      @range['cidrIp']
    end

    def to_str
      cidr_ip
    end
  end

  class IpPermissionGroup
    def initialize(gp)
      @gp = gp
    end

    def name
      @gp['groupName'] || @gp['groupId']
    end
  end

end
