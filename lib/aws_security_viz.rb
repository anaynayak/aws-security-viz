require_relative 'ec2/security_groups'
require_relative 'provider/json'
require_relative 'provider/ec2'
require_relative 'graph'
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
    render(g, output_file)
  end

  def build
    g = ENV["OBFUSCATE"] ? DebugGraph.new : Graph.new 
    @security_groups.each_with_index { |group, index|
      picker = ColorPicker.new(@options[:color])
      g.add_node(group.name)
      group.traffic.each { |traffic|
       if traffic.ingress
          g.add_edge(traffic.from, traffic.to, :color => picker.color(index, traffic.ingress), :style => 'bold', :label => traffic.port_range)
        else
          g.add_edge(traffic.to, traffic.from, :color => picker.color(index, traffic.ingress), :style => 'bold', :label => traffic.port_range)
        end
      }
    }
    g
  end

  def render(g, output_file)
    extension = File.extname(output_file)
    g.output(extension[1..-1].to_sym => output_file, :use => @config.format)
  end
end

