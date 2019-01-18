require 'json'

class JsonProvider
  def initialize(options)
    @groups = JSON.parse(File.read(options[:source_file]))['SecurityGroups']
  end

  def security_groups
    @groups.collect { |sg|
      Json::SecurityGroup.new(sg)
    }
  end
end

module Json
  class SecurityGroup
    def initialize(sg)
      @sg = sg
    end

    def name
      @sg['GroupName']
    end

    def group_id
      @sg['GroupId']
    end

    def vpc_id
      @sg['VpcId']
    end

    def ip_permissions
      @sg['IpPermissions'].collect { |ip|
        Json::IpPermission.new(ip)
      }
    end

    def group_id
      @sg['GroupId']
    end

    def ip_permissions_egress
      @sg['IpPermissionsEgress'].collect { |ip|
        Json::IpPermission.new(ip)
      }
    end
  end

  class IpPermission
    def initialize(ip)
      @ip = ip
    end

    def protocol
      @ip['IpProtocol']
    end

    def from
      @ip['FromPort']
    end

    def to
      @ip['ToPort']
    end

    def ip_ranges
      @ip['IpRanges'].collect { |gp|
        Json::IpPermissionRange.new(gp)
      }
    end

    def groups
      @ip['UserIdGroupPairs'].collect { |pair|
        Json::IpPermissionGroup.new(pair)
      }
    end

  end

  class IpPermissionRange
    def initialize(range)
      @range = range
    end

    def cidr_ip
      @range['CidrIp']
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
      @gp['GroupName'] || @gp['GroupId']
    end
  end
end
