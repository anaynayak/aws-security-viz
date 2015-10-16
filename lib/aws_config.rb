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

  def self.load(file)
    config_opts = File.exist?(file) ? YAML.load_file(file) : {}
    AwsConfig.new(config_opts)
  end

  def self.write(file)
    FileUtils.cp(File.expand_path('../opts.yml.sample', __FILE__), file)
  end
end
