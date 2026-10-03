# frozen_string_literal: true

require_relative "aws_security_viz/ec2/security_groups"
require_relative "aws_security_viz/provider/json"
require_relative "aws_security_viz/provider/ec2"
require_relative "aws_security_viz/renderer/all"
require_relative "aws_security_viz/graph"
require_relative "aws_security_viz/graph_filter"
require_relative "aws_security_viz/exclusions"
require_relative "aws_security_viz/debug_graph"
require_relative "aws_security_viz/color_picker"
require_relative "aws_security_viz/aws_config"
require_relative "aws_security_viz/cli_guard"

module AwsSecurityViz
  class VisualizeAws
    def initialize(config, options = {})
      @options = options
      @config = config
      provider = options[:source_file].nil? ? Ec2Provider.new(options) : JsonProvider.new(options)
      @security_groups = SecurityGroups.new(provider, config)
    end

    def unleash(output_file)
      g = build
      g.filter(@options[:source_filter], @options[:target_filter])
      g.output(Renderer.pick(@options[:renderer], output_file, @config))
    end

    def build
      g = @config.obfuscate? ? DebugGraph.new(@config) : Graph.new(@config)
      peer_names = {}
      @security_groups.each_with_index { |group, index|
        picker = ColorPicker.new(@options[:color])
        peer_names.merge!(@security_groups.peer_names(group))
        g.add_node(group.id, {label: group.name, vpc_id: group.vpc_id, group_id: group.id})
        @security_groups.traffic(group).each { |traffic|
          if traffic.ingress
            g.add_edge(traffic.from, traffic.to, color: picker.color(index, traffic.ingress), label: traffic.port_range)
          else
            g.add_edge(traffic.to, traffic.from, color: picker.color(index, traffic.ingress), label: traffic.port_range)
          end
        }
      }
      peer_names.each { |id, name| g.describe_node(id, {label: name}) }
      g
    end
  end
end
