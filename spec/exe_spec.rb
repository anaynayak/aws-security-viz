# frozen_string_literal: true

require "spec_helper"
require "open3"
require "tmpdir"

describe "exe/aws_security_viz" do
  def run_exe(*args, env: {})
    root = File.expand_path("..", __dir__)
    Dir.mktmpdir { |dir|
      cmd = ["bundle", "exec", "ruby", "-I", "lib", "-r", "./spec/fixtures/stub_ec2.rb", "exe/aws_security_viz",
        "-f", File.join(dir, "out.json"), *args]
      env = {"AWS_REGION" => nil, "AWS_PROFILE" => nil, "AWS_DEFAULT_REGION" => nil}.merge(env)
      _out, err, _status = Open3.capture3(env, *cmd, chdir: root)
      return err
    }
  end

  it "takes the region from the SDK chain when --region is not given" do
    err = run_exe(env: {"AWS_REGION" => "eu-west-2"})
    expect(err).not_to include("region:")
    expect(err).to include("CLIENT {stub_responses: true} ")
  end

  it "ignores AWS_PROFILE for static keys, leaving the SDK to read it" do
    err = run_exe("-a", "AKIAEXPLICIT", "-s", "secret", env: {"AWS_REGION" => "eu-west-2", "AWS_PROFILE" => "nope"})
    expect(err).to include("access_key_id: \"AKIAEXPLICIT\"")
    expect(err).not_to include("profile")
  end
end
