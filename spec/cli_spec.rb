# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "tmpdir"
require "json"
require "aws_security_viz/cli"

describe AwsSecurityViz::CLI do
  let(:source) { File.expand_path("integration/dummy.json", __dir__) }
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }

  around do |example|
    Dir.mktmpdir { |dir|
      @dir = dir
      Dir.chdir(dir) { example.run }
    }
  end

  after { AwsSecurityViz.logger = nil }

  def cli(*argv, env: {})
    described_class.new(argv, env: env, out: out, err: err)
  end

  it "prints usage and exits 0 for --help and -h" do
    %w[--help -h].each do |flag|
      expect(cli(flag).run).to eq(0)
    end
    expect(out.string).to include("Usage:", "--input=FILE", "--output=FILE", "--layout=ENGINE")
  end

  it "prints the version and exits 0 for --version" do
    expect(cli("--version").run).to eq(0)
    expect(out.string).to include("aws_security_viz v#{AwsSecurityViz::VERSION}")
  end

  it "exits 1 with a message on stderr for an unknown flag" do
    expect(cli("--nope").run).to eq(1)
    expect(err.string).to include("[ERROR]", "--nope")
    expect(out.string).to be_empty
  end

  it "accepts --input and --output as aliases of --source-file and --filename" do
    expect(cli("--input", source, "--output", "a.json").run).to eq(0)
    expect(cli("--source-file", source, "--filename", "b.json").run).to eq(0)
    expect(File.read("a.json")).to eq(File.read("b.json"))
  end

  it "creates the config file for both setup and init" do
    expect(cli("setup", "-c", "one.yml").run).to eq(0)
    expect(cli("init", "-c", "two.yml").run).to eq(0)
    expect(File.exist?("one.yml") && File.exist?("two.yml")).to be(true)
    expect(out.string).to include("one.yml created")
  end

  it "warns on stderr that --color is deprecated and still succeeds" do
    expect(cli("-o", source, "--color", "-f", "c.json").run).to eq(0)
    expect(err.string).to include("[WARN] --color is deprecated")
    expect(out.string).to be_empty
  end

  it "reads DEBUG and OBFUSCATE as booleans and logs debug output to stderr" do
    expect(cli("-o", source, "-f", "d.json", env: {"DEBUG" => "true", "OBFUSCATE" => "1"}).run).to eq(0)
    expect(err.string).to include("[DEBUG] node:")
    expect(out.string).to be_empty
    expect(File.read("d.json")).not_to include("sg-appgrp")
  end

  it "lets an explicit --no-debug and --no-obfuscate override DEBUG=true and OBFUSCATE=true" do
    env = {"DEBUG" => "true", "OBFUSCATE" => "true"}
    expect(cli("-o", source, "-f", "n.json", "--no-debug", "--no-obfuscate", env: env).run).to eq(0)
    expect(err.string).not_to include("[DEBUG]")
    expect(File.read("n.json")).to include("sg-appgrp")
  end

  it "infers the output format from the file extension without a deprecation warning" do
    {"a.json" => /\A\{"nodes"/, "a.html" => /<html/i, "a.mmd" => /\Aflowchart|\Agraph/, "a.dot" => /digraph/}.each do |file, pattern|
      expect(cli("-o", source, "-f", file).run).to eq(0), file
      expect(File.read(file)).to match(pattern), file
    end
    expect(err.string).not_to include("deprecated")
  end

  it "writes aws-security-viz.html by default" do
    expect(cli("-o", source).run).to eq(0)
    expect(File.read("aws-security-viz.html")).to match(/<html/i)
  end

  it "warns that --renderer is deprecated but still honours it" do
    expect(cli("-o", source, "-n", "json", "-f", "r.out").run).to eq(0)
    expect(err.string).to include("--renderer is deprecated")
    expect(JSON.parse(File.read("r.out"))).to have_key("nodes")
  end

  it "maps --renderer navigator to the html viewer with a warning" do
    expect(cli("-o", source, "-n", "navigator").run).to eq(0)
    expect(err.string).to include("--renderer navigator is deprecated")
    expect(File.read("aws-security-viz.html")).to match(/<html/i)
  end

  it "no longer accepts --serve" do
    expect(cli("--serve=3000", "-o", source, "-f", "x.json").run).to eq(1)
    expect(err.string).to include("invalid option: --serve")
  end

  it "returns 1 for an unknown renderer and invalid boolean env" do
    expect(cli("-o", source, "-n", "bogus").run).to eq(1)
    expect(err.string).to include("unknown renderer 'bogus'")
    expect(cli("-o", source, "-f", "x.json", env: {"DEBUG" => "maybe"}).run).to eq(1)
    expect(err.string).to include("DEBUG must be true, false, 1 or 0")
  end

  it "returns 130 on Ctrl-C" do
    allow(AwsSecurityViz::VisualizeAws).to receive(:new).and_raise(Interrupt)
    expect(cli("-o", source, "-f", "x.json").run).to eq(130)
  end

  it "passes --profile, --region and --vpc-id through to the provider options" do
    seen = nil
    allow(AwsSecurityViz::VisualizeAws).to receive(:new) { |_config, opts|
      seen = opts
      instance_double(AwsSecurityViz::VisualizeAws, unleash: nil)
    }
    cli("-p", "work", "-r", "eu-west-2", "-v", "vpc-1", "-f", "x.json").run
    expect(seen).to include(profile: "work", region: "eu-west-2", vpc_id: "vpc-1")
  end
end

describe AwsSecurityViz::CLI, "--all-regions" do
  it "sets all_regions in the provider options" do
    seen = nil
    allow(AwsSecurityViz::VisualizeAws).to receive(:new) { |_config, opts|
      seen = opts
      instance_double(AwsSecurityViz::VisualizeAws, unleash: nil)
    }
    described_class.new(%w[--all-regions -n json -f x.json], env: {}, out: StringIO.new, err: StringIO.new).run
    expect(seen).to include(all_regions: true)
  end
end

describe AwsSecurityViz::CLI, "argument validation" do
  let(:source) { File.expand_path("integration/dummy.json", __dir__) }
  let(:err) { StringIO.new }

  around do |example|
    Dir.mktmpdir { |dir| Dir.chdir(dir) { example.run } }
  end

  after { AwsSecurityViz.logger = nil }

  def run_cli(*argv)
    described_class.new(argv, env: {}, out: StringIO.new, err: err).run
  end

  it "accepts --no-debug, --no-obfuscate and --no-color" do
    %w[--no-debug --no-obfuscate --no-color].each do |flag|
      expect(run_cli(flag, "-o", source, "-f", "x.json")).to eq(0), flag
    end
  end

  it "rejects an unknown positional argument with exit 1" do
    expect(run_cli("bogus", "-o", source, "-f", "x.json")).to eq(1)
    expect(err.string).to include("unknown command 'bogus'")
    expect(File.exist?("x.json")).to be(false)
  end

  it "warns when --region or --all-regions is used with --source-file" do
    ["--region=eu-west-1", "--all-regions"].each do |flag|
      err.truncate(0)
      expect(run_cli(flag, "-o", source, "-f", "x.json")).to eq(0)
      expect(err.string).to include("--region and --all-regions are ignored with --source-file")
    end
  end
end
