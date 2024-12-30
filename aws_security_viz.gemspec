lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'version'

Gem::Specification.new do |s|
  s.name        = 'aws_security_viz'
  s.version     = AwsSecurityViz::VERSION
  s.version     = "#{s.version}-alpha-#{ENV['ALPHA_BUILD_NUMBER']}" if ENV['ALPHA_BUILD_NUMBER']
  s.date        = Time.now.strftime('%Y-%m-%d')
  s.summary     = 'Visualize your aws security groups'
  s.description = 'Provides a quick mechanism to visualize your EC2 security groups in multiple formats'
  s.authors     = ['Anay Nayak']
  s.email       = 'anayak007+rubygems@gmail.com'
  s.files       = %w(lib config)
  s.homepage    = 'https://github.com/anaynayak/aws-security-viz'
  s.license     = 'MIT'
  s.bindir      = 'exe'

  s.files = `git ls-files -z`.split("\x0")
  s.executables   = s.files.grep(%r{^exe/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']

  s.add_development_dependency 'rake', '>= 12.0.0', '~> 13.0'
  s.add_development_dependency 'rspec', '~> 3.5', '>= 3.5.0'
  if ENV["COVERAGE"]
    s.add_development_dependency "simplecov"
  end
  s.add_runtime_dependency 'rexml', '~> 3.2', '>= 3.2.2'
  s.add_runtime_dependency 'graphviz', '~> 1.1', '>= 1.1.0'
  s.add_runtime_dependency 'optimist', '>= 3.0', '< 3.3'
  s.add_runtime_dependency 'organic_hash', '~> 1.0', '>= 1.0.2'
  s.add_runtime_dependency 'rgl', '~> 0.5.3'
  s.add_runtime_dependency 'webrick', '~> 1.8.1'
  s.add_runtime_dependency 'aws-sdk-ec2', '>= 1.65', '< 1.432'

  s.required_ruby_version = '>= 3.0.0'
end

