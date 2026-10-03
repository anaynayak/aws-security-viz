# frozen_string_literal: true

module AwsSecurityViz
  # Flags ingress open to the whole internet on a sensitive port. It looks at the real rule (before
  # CIDR group mapping, merging and obfuscation), so a merged "all" label or a renamed peer cannot hide it.
  module Risk
    DEFAULT_PORTS = [22, 3389, 3306, 5432, 1433, 6379, 9200, 27017].freeze
    PUBLIC_CIDRS = %w[0.0.0.0/0 ::/0].freeze
    TCP = %w[tcp 6].freeze

    def self.risky?(rule, peer, ports)
      return false unless %i[cidr4 cidr6].include?(peer.kind) && PUBLIC_CIDRS.include?(peer.id)
      return true if rule.protocol.to_s == "-1"
      return false unless TCP.include?(rule.protocol.to_s) && rule.from_port && rule.to_port
      ports.any? { |port| port.between?(rule.from_port, rule.to_port) }
    end
  end
end
