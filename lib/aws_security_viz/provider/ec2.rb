# frozen_string_literal: true

require "aws-sdk-ec2"
require_relative "../model"

module AwsSecurityViz
  class Ec2Provider
    def initialize(options, client: nil)
      @options = options
      @client = client || Aws::EC2::Client.new(client_options(options))
    end

    def security_groups
      params = {}
      params[:filters] = [{name: "vpc-id", values: [@options[:vpc_id]]}] if @options[:vpc_id]
      groups = @client.describe_security_groups(params).flat_map { |page|
        page.security_groups.collect { |sg| SecurityGroup.from_hash(Model.normalize(sg.to_h)) }
      }
      Model.resolve_peer_names(groups)
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
end
