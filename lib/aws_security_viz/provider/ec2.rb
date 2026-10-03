# frozen_string_literal: true

require "aws-sdk-ec2"

module AwsSecurityViz
  class Ec2Provider
    def initialize(options, client: nil)
      @options = options
      @client = client || Aws::EC2::Client.new(client_options(options))
    end

    def security_groups
      params = {}
      params[:filters] = [{name: "vpc-id", values: [@options[:vpc_id]]}] if @options[:vpc_id]
      @client.describe_security_groups(params).flat_map { |page|
        page.security_groups.collect { |sg| Ec2::SecurityGroup.new(sg) }
      }
    end

    private

    # Region is left to the SDK default chain (AWS_REGION, profile) unless given.
    # An explicit profile wins over static keys so the SSO/shared-config login is used.
    def client_options(options)
      conn_opts = {region: options[:region], profile: options[:profile]}
      unless options[:profile]
        conn_opts.merge!(
          access_key_id: options[:access_key],
          secret_access_key: options[:secret_key],
          session_token: options[:session_token]
        )
      end
      conn_opts.delete_if { |_k, v| v.nil? }
    end
  end

  module Ec2
    class SecurityGroup
      extend Forwardable

      def_delegators :@sg, :group_id, :vpc_id
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
        @ip["ip_protocol"]
      end

      def from
        @ip["from_port"]
      end

      def to
        @ip["to_port"]
      end

      def ip_ranges
        @ip["ip_ranges"].collect { |gp|
          Ec2::IpPermissionRange.new(gp)
        }
      end

      def ipv6_ranges
        (@ip["ipv_6_ranges"] || []).collect { |range|
          Ec2::IpPermissionRange.new(range, "cidr_ipv_6")
        }
      end

      def prefix_lists
        (@ip["prefix_list_ids"] || []).collect { |pl|
          Ec2::IpPermissionRange.new(pl, "prefix_list_id")
        }
      end

      def groups
        @ip["user_id_group_pairs"].collect { |gp|
          Ec2::IpPermissionGroup.new(gp)
        }
      end
    end

    class IpPermissionRange
      def initialize(range, key = "cidr_ip")
        @range = range
        @key = key
      end

      def cidr_ip
        @range[@key]
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
        @gp["group_name"] || @gp["group_id"]
      end

      def group_id
        @gp["group_id"]
      end
    end
  end
end
