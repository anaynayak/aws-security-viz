lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'version'

Gem::Specification.new do |s|
  s.name        = 'aws_security_viz'
  s.version     = AwsSecurityViz::VERSION
  s.version     = "#{s.version}-alpha-#{ENV['TRAVIS_BUILD_NUMBER']}" if ENV['TRAVIS']
  s.date        = '2015-10-15'
  s.summary     = "Visualize your aws security groups"
  s.description = "Provides a quick mechanism to visualize your EC2 security groups in multiple formats"
  s.authors     = ["Anay Nayak"]
  s.email       = 'anayak007+rubygems@gmail.com'
  s.files       = ["lib", "config"]
  s.homepage    = 'https://github.com/anaynayak/aws-security-viz'
  s.license     = 'MIT'
  s.bindir      = 'exe'

  s.files = `git ls-files -z`.split("\x0")
  s.executables   = s.files.grep(%r{^exe/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_development_dependency "bundler", "~> 1.13"
  s.add_development_dependency "rake", "~> 11.2.2"
  s.add_development_dependency "rspec", "~> 3.5.0"

  s.add_runtime_dependency 'ruby-graphviz', "~> 1.2.2"
  s.add_runtime_dependency 'fog-aws', "~> 0.11.0"
  s.add_runtime_dependency 'unf', "~> 0.1.4"
  s.add_runtime_dependency 'json', "~> 2.0.2"
  s.add_runtime_dependency 'trollop', "~> 2.1.2"
  s.add_runtime_dependency 'organic_hash', "~> 1.0.2"

  s.required_ruby_version = '>= 2.0.0'
end

