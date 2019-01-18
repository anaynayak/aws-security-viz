require_relative 'ec2/security_groups'
require_relative 'provider/json'
require_relative 'provider/ec2'
require_relative 'renderer/all'
require_relative 'graph'
require_relative 'graph_filter'
require_relative 'exclusions'
require_relative 'debug_graph'
require_relative 'color_picker'
require_relative 'aws_config'

class VisualizeAws
  def initialize(config, options={})
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
    @security_groups.each_with_index { |group, index|
      picker = ColorPicker.new(@options[:color])
      g.add_node(group.name, {vpc_id: group.vpc_id, group_id: group.group_id})
      group.traffic.each { |traffic|
        if traffic.ingress
          g.add_edge(traffic.from, traffic.to, :color => picker.color(index, traffic.ingress), :label => traffic.port_range)
        else
          g.add_edge(traffic.to, traffic.from, :color => picker.color(index, traffic.ingress), :label => traffic.port_range)
        end
      }
    }
    g
  end

end

