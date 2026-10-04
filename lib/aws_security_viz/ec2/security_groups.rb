# frozen_string_literal: true

require_relative "../model"
require_relative "../risk"

module AwsSecurityViz
  class SecurityGroups
    include Enumerable

    def initialize(provider, config)
      @groups = provider.security_groups
      @config = config
    end

    def each(&block)
      @groups.reject { |sg| @config.exclusions.match(sg.name) }.each(&block)
    end

    def size
      @groups.size
    end

    # Group id -> name for referenced groups whose name is known.
    def peer_names(group)
      directed_rules(group).flat_map { |rule, _| rule.peers }
        .select { |p| p.kind == :group && p.name != p.id }.to_h { |p| [p.id, p.name] }
    end

    # Peer id -> :cidr4, :cidr6 or :prefix_list for the non-group peers a group's rules name, so renderers can draw them by kind.
    def peer_kinds(group)
      (group.ingress + group.egress).flat_map(&:peers).reject { |p| p.kind == :group }.to_h { |p| [p.id, p.kind] }
    end

    # Every rule of a group, both directions whatever --no-egress says, one entry per peer, for the viewer's path
    # query (which needs the egress side of a hop even when egress edges are not drawn). dir is "in" or "out";
    # node is the graph node the peer is drawn as when that differs from the peer id (CIDR group mapping).
    def path_rules(group)
      mapper = CidrGroupMapping.new(@groups, @config.groups, rule_peer_names(group))
      rules = group.ingress.map { |r| [r, "in"] } + group.egress.map { |r| [r, "out"] }
      rules.flat_map { |rule, dir|
        rule.peers.reject { |peer| @config.exclusions.match(peer.name) }.map { |peer|
          text = peer.description.to_s.strip
          node = mapper.key(peer.id)
          {dir: dir, proto: PortLabel.protocol(rule.protocol), from: rule.from_port, to: rule.to_port,
           kind: peer.kind.to_s, peer: peer.id, node: (node unless node == peer.id), desc: (text unless text.empty?)}.compact
        }
      }.uniq
    end

    def traffic(group)
      all_traffic = directed_rules(group).flat_map { |rule, ingress| rule_traffic(group, rule, ingress) }.uniq
      CidrGroupMapping.new(@groups, @config.groups, peer_names(group)).map(all_traffic)
    end

    private

    def rule_peer_names(group)
      (group.ingress + group.egress).flat_map(&:peers).select { |p| p.kind == :group && p.name != p.id }.to_h { |p| [p.id, p.name] }
    end

    # [rule, ingress?] pairs; egress rules only when configured.
    def directed_rules(group)
      rules = group.ingress.map { |r| [r, true] }
      @config.egress? ? rules + group.egress.map { |r| [r, false] } : rules
    end

    def rule_traffic(group, rule, ingress)
      rule.peers.reject { |peer| @config.exclusions.match(peer.name) }.map { |peer|
        text = peer.description.to_s.strip
        Traffic.new(ingress: ingress, from: peer.id, to: group.id, port_range: rule.port_range,
          risky: ingress && Risk.risky?(rule, peer, @config.risky_ports),
          descriptions: text.empty? ? [] : [{ports: rule.port_range, text: text}])
      }
    end
  end

  class CidrGroupMapping
    def initialize(all_groups, user_groups, peer_names = {})
      @all_groups = all_groups
      @user_groups = user_groups
      @peer_names = peer_names
    end

    def map(all_traffic)
      traffic = all_traffic.collect { |traffic|
        traffic.with(from: mapping(traffic.from), to: mapping(traffic.to))
      }
      traffic.uniq.group_by { |t| [t.from, t.to, t.ingress] }.collect { |k, v| Traffic.grouped(v) }.uniq
    end

    # The graph node a peer id is drawn as.
    def key(val) = mapping(val)

    private

    def mapping(val)
      group = @all_groups.find { |g| g.id == val }
      name = group ? group.name : @peer_names[val]
      @user_groups[val] || (name && @user_groups[name]) || val
    end
  end
end
