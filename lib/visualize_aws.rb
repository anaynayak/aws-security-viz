require 'graphviz'
require 'trollop'
require_relative 'ec2/security_groups'

class VisualizeAws
  def initialize(options={})
    @security_groups = SecurityGroups.new(options)
  end

  def unleash(output_file)
    g = build
    render(g, output_file)
  end

  def build
    g = GraphViz::new('G')
    @security_groups.each { |group|
      g.add_node(group.name)
      group.traffic.each { |traffic|
        g.add_edge(traffic.from, traffic.to, :color => traffic.ingress ? 'blue' : 'red', :style => 'bold', :label => traffic.port_range)
      }
    }
    g
  end

  def render(g, output_file)
    extension = File.extname(output_file)
    g.output(extension[1..-1].to_sym => output_file)
  end
end

if __FILE__ == $0
  opts = Trollop::options do
    opt :access_key, 'AWS access key', :type => :string
    opt :secret_key, 'AWS secret key', :type => :string
    opt :filename, 'Output file name', :type => :string, :default => 'aws-security-viz.png'
  end
  Trollop::die :access_key, 'is required' if opts[:access_key].nil?
  Trollop::die :secret_key, 'is required' if opts[:secret_key].nil?
  VisualizeAws.new(opts).unleash(opts[:filename])
end
