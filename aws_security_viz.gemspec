lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'version'

Gem::Specification.new do |s|
  s.name        = 'aws_security_viz'
  s.version     = AwsSecurityViz::VERSION
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

  s.add_development_dependency "bundler", "~> 1.9"
  s.add_development_dependency "rake", "~> 10.0"
  s.add_development_dependency "rspec", "~> 3.1.0"

  s.add_runtime_dependency 'ruby-graphviz', "~> 1.2.1"
  s.add_runtime_dependency 'fog', "~> 1.26.0"
  s.add_runtime_dependency 'unf', "~> 0.1.4"
  s.add_runtime_dependency 'json', "~> 1.8.1"
  s.add_runtime_dependency 'trollop', "~> 2.1.1"
  s.add_runtime_dependency 'organic_hash', "~> 1.0.2"
end

