# frozen_string_literal: true

require "aws-sdk-ec2"
require_relative "../model"

module AwsSecurityViz
  class Ec2Provider
    # client: a single injected client (used as-is, one region); otherwise one client is built per region.
    def initialize(options, client: nil)
      @options = options
      @client = client
    end

    def security_groups
      regions = @client ? [nil] : region_list
      groups = regions.flat_map { |region| describe(@client || build_client(region), (regions.size > 1) ? region : nil) }
      Model.resolve_peer_names(groups)
    end

    private

    def describe(client, region)
      params = {}
      params[:filters] = [{name: "vpc-id", values: [@options[:vpc_id]]}] if @options[:vpc_id]
      client.describe_security_groups(params).flat_map { |page|
        page.security_groups.collect { |sg| SecurityGroup.from_hash(Model.normalize(sg.to_h)).with(region: region) }
      }
    end

    # [nil] means one client on the SDK default region chain (AWS_REGION, profile).
    def region_list
      raise ArgumentError, "--region and --all-regions cannot be combined" if @options[:all_regions] && @options[:region]
      return build_client(nil).describe_regions.regions.map(&:region_name).sort if @options[:all_regions]
      names = @options[:region].to_s.split(",").map(&:strip).reject(&:empty?).uniq
      names.empty? ? [nil] : names
    end

    def build_client(region)
      Aws::EC2::Client.new(client_options(@options, region))
    end

    # An explicit profile wins over static keys so the SSO/shared-config login is used.
    def client_options(options, region)
      conn_opts = {region: region, profile: options[:profile]}
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
end
