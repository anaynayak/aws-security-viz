# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "aws_security_viz/version"

Gem::Specification.new do |s|
  s.name = "aws_security_viz"
  s.version = AwsSecurityViz::VERSION
  s.summary = "Visualize your aws security groups"
  s.description = "Provides a quick mechanism to visualize your EC2 security groups in multiple formats"
  s.authors = ["Anay Nayak"]
  s.email = "anayak007+rubygems@gmail.com"
  s.homepage = "https://github.com/anaynayak/aws-security-viz"
  s.license = "MIT"
  s.metadata = {
    "source_code_uri" => "https://github.com/anaynayak/aws-security-viz",
    "changelog_uri" => "https://github.com/anaynayak/aws-security-viz/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  s.bindir = "exe"
  s.files = Dir["lib/**/*", "exe/*"] + %w[LICENSE.md README.md CHANGELOG.md]
  s.executables = Dir.children("exe")
  s.require_paths = ["lib"]

  s.add_runtime_dependency "rexml", ">= 3.4.4"
  s.add_runtime_dependency "optimist", ">= 3.0"
  s.add_runtime_dependency "webrick", ">= 1.8.1"
  s.add_runtime_dependency "aws-sdk-ec2", ">= 1.400"

  s.required_ruby_version = ">= 3.3"
end
