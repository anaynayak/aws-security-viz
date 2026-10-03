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

    def traffic(group)
      all_traffic = directed_rules(group).flat_map { |rule, ingress| rule_traffic(group, rule, ingress) }.uniq
      CidrGroupMapping.new(@groups, @config.groups, peer_names(group)).map(all_traffic)
    end

    private

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

    private

    def mapping(val)
      group = @all_groups.find { |g| g.id == val }
      name = group ? group.name : @peer_names[val]
      @user_groups[val] || (name && @user_groups[name]) || val
    end
  end
end
