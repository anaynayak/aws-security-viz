require 'aws-sdk-ec2'

class Ec2Provider

  def initialize(options)
    @options = options
    conn_opts = {
      region: options[:region],
      access_key_id: options[:access_key],
      secret_access_key: options[:secret_key],
      session_token: options[:session_token]
    }.delete_if {|k,v| v.nil?}

    @client = Aws::EC2::Client.new(conn_opts)
  end

  def security_groups
    @client.describe_security_groups.security_groups.reject { |sg|
      @options[:vpc_id] && sg.vpc_id != @options[:vpc_id]
    }.collect { |sg|
      Ec2::SecurityGroup.new(sg)
    }
  end
end

module Ec2
  class SecurityGroup
    extend Forwardable
    def_delegators :@sg, :name, :group_id, :vpc_id
    def initialize(sg)
      @sg = sg
    end

    def name
      @sg.group_name
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
      @ip['ip_protocol']
    end

    def from
      @ip['from_port']
    end

    def to
      @ip['to_port']
    end

    def ip_ranges
      @ip['ip_ranges'].collect {|gp|
        Ec2::IpPermissionRange.new(gp)
      }
    end

    def groups
      @ip['user_id_group_pairs'].collect {|gp|
        Ec2::IpPermissionGroup.new(gp)
      }
    end
  end

  class IpPermissionRange
    def initialize(range)
      @range = range
    end

    def cidr_ip
      @range['cidr_ip']
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
      @gp['group_name'] || @gp['group_id']
    end
  end

end
