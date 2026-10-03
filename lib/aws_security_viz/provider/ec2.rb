# frozen_string_literal: true

require "aws-sdk-ec2"
require_relative "../model"
require_relative "../logging"

module AwsSecurityViz
  class Ec2Provider
    # Per-region failures that must not abort a multi-region run (region not enabled, no permission).
    SKIPPABLE_ERRORS = [Aws::EC2::Errors::UnauthorizedOperation, Aws::EC2::Errors::AuthFailure, Aws::EC2::Errors::OptInRequired].freeze

    # client: a single injected client (used as-is, one region); otherwise one client is built per region.
    def initialize(options, client: nil)
      @options = options
      @client = client
    end

    def security_groups
      regions = @client ? [nil] : region_list
      errors = []
      groups = regions.flat_map do |region|
        describe(@client || build_client(region), (regions.size > 1) ? region : nil)
      rescue *SKIPPABLE_ERRORS => e
        raise if regions.size == 1
        AwsSecurityViz.logger.warn("skipping region #{region}: #{e.class.name.split("::").last}: #{e.message}")
        errors << e
        []
      end
      raise errors.first if errors.size == regions.size
      Model.resolve_peer_names(groups)
    end

    private

    def describe(client, region)
      params = {}
      params[:filters] = [{name: "vpc-id", values: [@options[:vpc_id]]}] if @options[:vpc_id]
      groups = client.describe_security_groups(params).flat_map { |page|
        page.security_groups.collect { |sg| SecurityGroup.from_hash(Model.normalize(sg.to_h)).with(region: region) }
      }
      return groups unless @options[:show_unused]
      used = begin
        attached_group_ids(client, params)
      rescue Aws::EC2::Errors::UnauthorizedOperation
        # Without the permission the groups are still worth drawing; just leave them unmarked.
        AwsSecurityViz.logger.warn("--show-unused needs ec2:DescribeNetworkInterfaces; no groups are marked unused#{" in #{region}" if region}")
        return groups
      end
      groups.map { |g| g.with(unused: !used.include?(g.id)) }
    end

    # Ids of groups attached to at least one network interface (extra call, only for --show-unused).
    def attached_group_ids(client, params)
      client.describe_network_interfaces(params).each_with_object(Set.new) { |page, ids|
        page.network_interfaces.each { |eni| eni.groups.each { |g| ids << g.group_id } }
      }
    end

    # [nil] means one client on the SDK default region chain (AWS_REGION, profile).
    def region_list
      names = @options[:region].to_s.split(",").map(&:strip).reject(&:empty?).uniq
      # With --all-regions, -r only names the region used to call DescribeRegions.
      return build_client(names.first).describe_regions.regions.map(&:region_name).sort if @options[:all_regions]
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
