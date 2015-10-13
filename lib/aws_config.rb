class AwsConfig
  def initialize(opts={})
    @opts = opts
  end

  def exclusions
    @exclusions ||=Exclusions.new(@opts[:exclude])
  end

  def groups
    @opts[:groups] || {}
  end

  def format
    @opts[:format] || 'dot'
  end

  def self.load
    config_opts = File.exist?('opts.yml') ? YAML.load_file('opts.yml') : {}
    AwsConfig.new(config_opts)
  end
end
