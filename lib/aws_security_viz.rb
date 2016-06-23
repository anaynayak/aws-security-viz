require_relative 'ec2/security_groups'
require_relative 'provider/json'
require_relative 'provider/ec2'
require_relative 'renderer/graphviz'
require_relative 'renderer/json'
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
    if output_file.end_with?('json')
      g.output(Renderer::Json.new(output_file, @config))
      FileUtils.copy(File.expand_path('../export/html/view.html', __FILE__),
                     File.expand_path('../view.html', output_file))
    else
      g.output(Renderer::GraphViz.new(output_file, @config))
    end
  end

  def build
    g = @config.obfuscate? ? DebugGraph.new(@config) : Graph.new(@config)
    @security_groups.each_with_index { |group, index|
      picker = ColorPicker.new(@options[:color])
      g.add_node(group.name, group.labels)
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

