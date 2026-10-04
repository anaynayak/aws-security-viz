# frozen_string_literal: true

require_relative "port_label"

module AwsSecurityViz
  # Where a rule's traffic comes from or goes to. kind is :cidr4, :cidr6, :prefix_list or :group;
  # id is the CIDR, prefix list id or group id and name is what exclusions and labels match on.
  # description is the free-text rule description (nil or empty when none was given).
  Peer = Data.define(:kind, :id, :name, :description) do
    def initialize(kind:, id:, name: nil, description: nil)
      super(kind: kind, id: id, name: name || id, description: description)
    end
  end

  Rule = Data.define(:protocol, :from_port, :to_port, :peers) do
    def port_range
      PortLabel.format(protocol, from_port, to_port)
    end
  end

  # region is only set when several regions are queried, so nodes can be grouped by region.
  # unused is true only when --show-unused found no network interface attached to the group.
  # unknown_sides lists "in" and "out" when the input had no rule list at all for that direction (an absent
  # IpPermissions or IpPermissionsEgress key, which is not the same as an empty list that denies everything).
  SecurityGroup = Data.define(:id, :name, :vpc_id, :ingress, :egress, :region, :unused, :unknown_sides) do
    def initialize(id:, name:, vpc_id:, ingress:, egress:, region: nil, unused: false, unknown_sides: [])
      super
    end

    # Builds a group from a describe-security-groups hash with snake_case keys (see Model.normalize).
    def self.from_hash(hash)
      new(
        id: hash[:group_id], name: hash[:group_name], vpc_id: hash[:vpc_id],
        ingress: (hash[:ip_permissions] || []).map { |ip| Rule.from_hash(ip) },
        egress: (hash[:ip_permissions_egress] || []).map { |ip| Rule.from_hash(ip) },
        unknown_sides: {"in" => :ip_permissions, "out" => :ip_permissions_egress}.reject { |_, key| hash.key?(key) }.keys
      )
    end
  end

  class Rule
    def self.from_hash(ip)
      peers = (ip[:ip_ranges] || []).map { |r| Peer.new(kind: :cidr4, id: r[:cidr_ip], description: r[:description]) } +
        (ip[:ipv6_ranges] || []).map { |r| Peer.new(kind: :cidr6, id: r[:cidr_ipv6], description: r[:description]) } +
        (ip[:prefix_list_ids] || []).map { |r| Peer.new(kind: :prefix_list, id: r[:prefix_list_id], description: r[:description]) } +
        (ip[:user_id_group_pairs] || []).map { |g| Peer.new(kind: :group, id: g[:group_id] || g[:group_name], name: g[:group_name], description: g[:description]) }
      new(protocol: ip[:ip_protocol], from_port: ip[:from_port], to_port: ip[:to_port], peers: peers)
    end
  end

  # descriptions: the non-empty rule descriptions behind this traffic, as {ports:, text:} hashes.
  # risky: public ingress on a sensitive port (see Risk), decided on the real rule.
  Traffic = Data.define(:ingress, :from, :to, :port_range, :descriptions, :risky) do
    def initialize(ingress:, from:, to:, port_range:, descriptions: [], risky: false)
      super
    end

    def self.grouped(traffic_list)
      t = traffic_list.first
      port_range = PortLabel.normalise(traffic_list.collect(&:port_range).join(","))
      new(ingress: t.ingress, from: t.from, to: t.to, port_range: port_range,
        descriptions: traffic_list.flat_map(&:descriptions).uniq, risky: traffic_list.any?(&:risky))
    end
  end

  module Model
    # Deep-converts the AWS CLI's PascalCase keys (and the SDK's ipv_6 spelling) to snake_case symbols.
    def self.normalize(value)
      case value
      when Hash then value.to_h { |k, v| [key(k), normalize(v)] }
      when Array then value.map { |v| normalize(v) }
      else value
      end
    end

    def self.key(name)
      name.to_s.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.sub("ipv_6", "ipv6").to_sym
    end

    # EC2 often omits GroupName in group peers; take it from the described groups so name-based
    # exclusions and labels see the real name (an id is the last resort).
    def self.resolve_peer_names(groups)
      names = groups.to_h { |g| [g.id, g.name] }
      resolve = ->(rule) {
        rule.with(peers: rule.peers.map { |p| (p.kind == :group && p.name == p.id) ? p.with(name: names[p.id] || p.id) : p })
      }
      groups.map { |g| g.with(ingress: g.ingress.map(&resolve), egress: g.egress.map(&resolve)) }
    end
  end
end
