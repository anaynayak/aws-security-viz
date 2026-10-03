# frozen_string_literal: true

require "yaml"

module AwsSecurityViz
  class AwsConfig
    def initialize(opts = {})
      @opts = opts
    end

    def exclusions
      @exclusions ||= Exclusions.new(@opts[:exclude])
    end

    def egress?
      @opts.key?(:egress) ? @opts[:egress] : true
    end

    def groups
      @opts[:groups] || {}
    end

    LAYOUTS = %w[dot neato sfdp fdp twopi circo].freeze

    # Graphviz layout engine: --layout, else `format` in opts.yml, else dot.
    def layout
      engine = (@opts[:layout] || @opts[:format] || "dot").to_s
      return engine if LAYOUTS.include?(engine)
      raise ArgumentError, "unknown layout engine '#{engine}' (choose from: #{LAYOUTS.join(", ")})"
    end

    def debug?
      @opts[:debug] || false
    end

    def obfuscate?
      @opts[:obfuscate] || false
    end

    # Parses an env-style flag: nil/empty is unset, true/1/yes/on and false/0/no/off are booleans.
    def self.boolean(value, name = "value")
      text = value.to_s.strip.downcase
      return nil if text.empty?
      return true if %w[true 1 yes on].include?(text)
      return false if %w[false 0 no off].include?(text)
      raise ArgumentError, "#{name} must be true, false, 1 or 0 (got '#{value}')"
    end

    def self.load(file)
      config_opts = File.exist?(file) ? YAML.load_file(file) : {}
      AwsConfig.new(config_opts)
    end

    def merge(opts)
      AwsConfig.new(@opts.merge!(opts))
    end

    def self.write(file)
      FileUtils.cp(File.expand_path("../opts.yml.sample", __FILE__), file)
    end
  end
end
