# frozen_string_literal: true

require "spec_helper"
require "open3"
require "tmpdir"
require "json"

# Drives exe/aws_security_viz as a subprocess against the bundled JSON fixture.
describe "exe/aws_security_viz options" do
  let(:root) { File.expand_path("..", __dir__) }
  let(:source) { File.join(root, "spec/integration/dummy.json") }

  def run_exe(*args, dir:, env: {})
    cmd = ["bundle", "exec", "ruby", "-I", "lib", "exe/aws_security_viz", "-o", source, "-c", File.join(dir, "opts.yml"), *args]
    env = {"DEBUG" => nil, "OBFUSCATE" => nil, "BUNDLE_GEMFILE" => File.join(root, "Gemfile")}.merge(env)
    Open3.capture3(env, *cmd, chdir: root)
  end

  around do |example|
    Dir.mktmpdir { |dir|
      @dir = dir
      example.run
    }
  end

  it "prints the valid choices and exits 1 for an unknown renderer" do
    out, _err, status = run_exe("--renderer", "bogus", "-f", File.join(@dir, "x"), dir: @dir)
    expect(status.exitstatus).to eq(1)
    expect(out).to include("unknown renderer 'bogus'", "graphviz, json, navigator")
  end

  it "warns that --color is deprecated and still runs" do
    out, err, status = run_exe("--color", "--renderer", "json", "-f", File.join(@dir, "c.json"), dir: @dir)
    expect(status.exitstatus).to eq(0)
    expect(out + err).to include("--color is deprecated")
  end

  it "rejects an unknown layout engine" do
    out, _err, status = run_exe("--layout", "bogus", "-f", File.join(@dir, "x.dot"), dir: @dir)
    expect(status.exitstatus).to eq(1)
    expect(out).to include("unknown layout engine 'bogus'")
  end

  it "takes the layout engine from opts.yml" do
    File.write(File.join(@dir, "opts.yml"), ":format: bogus\n")
    out, _err, status = run_exe("-f", File.join(@dir, "x.dot"), dir: @dir)
    expect(status.exitstatus).to eq(1)
    expect(out).to include("unknown layout engine 'bogus'")
  end

  it "treats OBFUSCATE=false as off and OBFUSCATE=1 / --obfuscate as on" do
    plain = File.join(@dir, "plain.json")
    run_exe("--renderer", "json", "-f", plain, env: {"OBFUSCATE" => "false"}, dir: @dir)
    expect(File.read(plain)).to include("sg-appgrp")

    %w[1 true].each do |value|
      hashed = File.join(@dir, "hashed#{value}.json")
      run_exe("--renderer", "json", "-f", hashed, env: {"OBFUSCATE" => value}, dir: @dir)
      expect(File.read(hashed)).not_to include("sg-appgrp")
    end

    flagged = File.join(@dir, "flagged.json")
    run_exe("--renderer", "json", "--obfuscate", "-f", flagged, dir: @dir)
    expect(File.read(flagged)).not_to include("sg-appgrp")
  end

  it "treats DEBUG=false as off, DEBUG=true and --debug as on" do
    base = ["--renderer", "json", "-f", File.join(@dir, "d.json")]
    off, = run_exe(*base, env: {"DEBUG" => "false"}, dir: @dir)
    expect(off).not_to include("node:")
    on, = run_exe(*base, env: {"DEBUG" => "true"}, dir: @dir)
    expect(on).to include("node:")
    flagged, = run_exe(*base, "--debug", dir: @dir)
    expect(flagged).to include("node:")
  end

  it "rejects an invalid boolean env value" do
    out, _err, status = run_exe("--renderer", "json", "-f", File.join(@dir, "d.json"), env: {"DEBUG" => "maybe"}, dir: @dir)
    expect(status.exitstatus).to eq(1)
    expect(out).to include("DEBUG must be true, false, 1 or 0")
  end

  it "names the default output after the renderer" do
    Dir.chdir(@dir) do
      cmd = ->(*args) { Open3.capture3({"DEBUG" => nil, "OBFUSCATE" => nil, "BUNDLE_GEMFILE" => File.join(root, "Gemfile")}, "bundle", "exec", "ruby", "-I", File.join(root, "lib"), File.join(root, "exe/aws_security_viz"), "-o", source, *args) }
      _out, _err, status = cmd.call("--renderer", "json")
      expect(status.exitstatus).to eq(0)
      expect(File.exist?("aws-security-viz.json")).to be(true)
      expect(File.exist?("aws-security-viz.png")).to be(false)
      _out, _err, status = cmd.call
      expect(status.exitstatus).to eq(0)
      expect(File.exist?("aws-security-viz.png")).to be(true)
    end
  end
end
