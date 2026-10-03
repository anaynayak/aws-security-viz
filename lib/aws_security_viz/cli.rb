# frozen_string_literal: true

require "optparse"
require_relative "version"
require_relative "logging"
require_relative "../aws_security_viz"

module AwsSecurityViz
  # Command line front end: `CLI.new(argv).run` returns the exit status (0, 1, or 130 on Ctrl-C).
  class CLI
    def initialize(argv, env: ENV, out: $stdout, err: $stderr)
      @argv = argv.dup
      @env = env
      @out = out
      @err = err
    end

    def run
      AwsSecurityViz.logger = AwsSecurityViz.build_logger(@err)
      opts = defaults
      parser = build_parser(opts)
      begin
        parser.parse!(@argv)
      rescue OptionParser::ParseError => e
        AwsSecurityViz.logger.error("#{e.message} (try --help)")
        return 1
      end
      return 0 if opts[:exit]
      command = @argv.shift
      unknown = [command, *@argv].compact.reject { |a| a == command && %w[setup init].include?(a) }
      unless unknown.empty?
        AwsSecurityViz.logger.error("unknown command '#{unknown.first}' (expected setup or init; try --help)")
        return 1
      end
      return setup(opts) if command
      if opts[:source_file] && (opts[:region] || opts[:all_regions])
        AwsSecurityViz.logger.warn("--region and --all-regions are ignored with --source-file")
      end
      if opts[:serve] && !(1..65535).cover?(opts[:serve])
        AwsSecurityViz.logger.error("--serve port must be between 1 and 65535, got #{opts[:serve]}")
        return 1
      end
      visualize(opts)
    end

    private

    def defaults
      {
        access_key: @env["AWS_ACCESS_KEY"] || @env["AWS_ACCESS_KEY_ID"],
        secret_key: @env["AWS_SECRET_KEY"] || @env["AWS_SECRET_ACCESS_KEY"],
        session_token: @env["AWS_SESSION_TOKEN"],
        config: "opts.yml",
        color: false,
        renderer: "graphviz",
        debug: false,
        obfuscate: false
      }
    end

    def build_parser(opts)
      OptionParser.new do |o|
        o.banner = "Usage: aws_security_viz [options] [setup|init]"
        o.on("-a", "--access-key=KEY", "AWS access key") { |v| opts[:access_key] = v }
        o.on("-s", "--secret-key=KEY", "AWS secret key") { |v| opts[:secret_key] = v }
        o.on("-e", "--session-token=TOKEN", "AWS session token") { |v| opts[:session_token] = v }
        o.on("-r", "--region=REGION", "AWS region(s) to query, comma-separated (default: SDK chain, e.g. AWS_REGION or profile)") { |v| opts[:region] = v }
        o.on("--all-regions", "Query every region returned by DescribeRegions") { opts[:all_regions] = true }
        o.on("-p", "--profile=NAME", "AWS shared-config profile to use (AWS_PROFILE is read by the SDK)") { |v| opts[:profile] = v }
        o.on("-v", "--vpc-id=ID", "AWS VPC id to show") { |v| opts[:vpc_id] = v }
        o.on("-o", "--source-file=FILE", "--input=FILE", "JSON source file containing security groups") { |v| opts[:source_file] = v }
        o.on("-f", "--filename=FILE", "--output=FILE", "Output file name (default: aws-security-viz.png, or .json for json/navigator)") { |v| opts[:filename] = v }
        o.on("-c", "--config=FILE", "Config file (opts.yml)") { |v| opts[:config] = v }
        o.on("-l", "--[no-]color", "Deprecated, ignored: edges are blue for ingress and red for egress") { |v| opts[:color] = v }
        o.on("-n", "--renderer=NAME", "Renderer (#{Renderer.all.join("|")}) (default: graphviz)") { |v| opts[:renderer] = v }
        o.on("-y", "--layout=ENGINE", "Graphviz layout engine (#{AwsConfig::LAYOUTS.join("|")}); overrides opts.yml format") { |v| opts[:layout] = v }
        o.on("-d", "--[no-]debug", "Verbose output and stack traces (or DEBUG=true)") { |v| opts[:debug] = v }
        o.on("-b", "--[no-]obfuscate", "Hash group names and ports (or OBFUSCATE=true)") { |v| opts[:obfuscate] = v }
        o.on("-u", "--source-filter=FILTER", "Source filter") { |v| opts[:source_filter] = v }
        o.on("-t", "--target-filter=FILTER", "Target filter") { |v| opts[:target_filter] = v }
        o.on("--serve=PORT", Integer, "Serve a HTTP server") { |v| opts[:serve] = v }
        o.on("-i", "--version", "Print version and exit") {
          @out.puts "aws_security_viz v#{VERSION}"
          opts[:exit] = true
        }
        o.on("-h", "--help", "Show this message") {
          @out.puts o
          opts[:exit] = true
        }
      end
    end

    def setup(opts)
      AwsConfig.write(opts[:config])
      @out.puts "#{opts[:config]} created in current directory."
      0
    end

    def visualize(opts)
      debug = false
      CliGuard.run(debug: -> { debug }) do
        AwsSecurityViz.logger.warn("--color is deprecated and ignored; edges are blue (ingress) or red (egress)") if opts[:color]
        debug = opts[:debug] || AwsConfig.boolean(@env["DEBUG"], "DEBUG")
        overrides = {
          obfuscate: opts[:obfuscate] || AwsConfig.boolean(@env["OBFUSCATE"], "OBFUSCATE"),
          debug: debug,
          layout: opts[:layout]
        }.compact
        config = AwsConfig.load(opts[:config]).merge(overrides)
        Renderer.validate!(opts[:renderer])
        filename = opts[:filename] || Renderer.default_file(opts[:renderer])
        VisualizeAws.new(config, opts).unleash(filename)
        serve(opts[:serve], filename) if opts[:serve]
      end
    end

    def serve(port, filename)
      require "webrick"
      @out.puts "Navigate to http://localhost:#{port}/navigator.html##{filename}"
      WEBrick::HTTPServer.new({Port: port, DocumentRoot: "."}).start
    end
  end
end
