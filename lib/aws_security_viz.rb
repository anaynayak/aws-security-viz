# frozen_string_literal: true

require_relative "aws_security_viz/ec2/security_groups"
require_relative "aws_security_viz/provider/json"
require_relative "aws_security_viz/provider/ec2"
require_relative "aws_security_viz/renderer/all"
require_relative "aws_security_viz/graph"
require_relative "aws_security_viz/graph_filter"
require_relative "aws_security_viz/exclusions"
require_relative "aws_security_viz/aws_config"
require_relative "aws_security_viz/cli_guard"

module AwsSecurityViz
  class VisualizeAws
    def initialize(config, options = {})
      @options = options
      @config = config
      provider = options[:source_file].nil? ? Ec2Provider.new(options.merge(obfuscate: config.obfuscate?)) : JsonProvider.new(options)
      @security_groups = SecurityGroups.new(provider, config)
    end

    def unleash(output_file)
      g = build
      g.filter(@options[:source_filter], @options[:target_filter])
      g.output(Renderer.pick(@options[:renderer], output_file, @config))
      g.risky_edge_count
    end

    # What the renderers get for a group. The rules (and which directions the input left out) are for the HTML
    # viewer's path query; an obfuscated report has neither, as they name groups, CIDRs and ports in clear text.
    def node_options(group)
      opts = {label: group.name, vpc_id: group.vpc_id, region: group.region, group_id: group.id}
      opts[:unused] = true if group.unused
      unless @config.obfuscate?
        opts[:rules] = @security_groups.path_rules(group)
        opts[:unknown] = group.unknown_sides unless group.unknown_sides.empty?
      end
      opts
    end

    def build
      g = Graph.new(@config)
      peer_names = {}
      @security_groups.each { |group|
        peer_names.merge!(@security_groups.peer_names(group))
        g.add_node(group.id, node_options(group))
        @security_groups.traffic(group).each { |traffic|
          edge = {color: traffic.ingress ? :blue : :red, label: traffic.port_range}
          edge[:risky] = true if traffic.risky
          edge[:descriptions] = traffic.descriptions unless traffic.descriptions.empty?
          if traffic.ingress
            g.add_edge(traffic.from, traffic.to, edge)
          else
            g.add_edge(traffic.to, traffic.from, edge)
          end
        }
      }
      peer_names.each { |id, name| g.describe_node(id, {label: name}) }
      g
    end
  end
end
