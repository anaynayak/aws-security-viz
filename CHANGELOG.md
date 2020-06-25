# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]
### Added
- --version option which prints aws-security-viz version

## [0.2.1] - 2020-06-20
### Added
- Provide a webserver using a --serve PORT which provides a link to the navigator view

### Changed
- Bumped InteractiveGraph to v0.3.2

### Fixed
- Empty InfoPanel in navigator view now shows vpc, security group name.

## [0.2.0] - 2019-01-24
### Added
- Add graph navigator renderer using https://grapheco.github.io/InteractiveGraph/

### Changed
- Renderer no longer identified automatically based on json file extension. 

## [0.1.6] - 2019-01-14
### Added
- Dockerfile

### Changed
- Replaced fog gem with aws-sdk-ec2
- Upgrade bundler to 2.x
- Removed unused dependencies

### Fixed
- Issue with --color=true failing with exception due to change in Graphviz library.

## [0.1.5] - 2018-10-10
### Added
- Filter by VPC id
- Support for AWS session token
- Use rankdir with graphviz to improve layout

### Changed
- Dependent trollop gem renamed to optimist
- Switched from ruby-graphviz to graphviz gem

## [0.1.4] - 2017-02-03
### Added
- CHANGELOG.md
- Support for AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
- Capability to view filtered view by source or target.

### Fixed
- Issue with vagrant up not working due to older bundler version and missing dependencies

## [0.1.3] - 2016-03-20
### Changed
- Removed ENV usage from the gem.

### Fixed
- Pointing to specific version of linkurious.js instead of master build
- Web view html and json files are now generated in the same directory.

### Added
- Support for credentials via ENV or .fog
- Capability to exclude egress via opts.yml file.


## [0.1.2] - 2015-12-19
### Added
- linkurious/sigma.js to render json representation of security groups
- Capability to exclude CIDR via opts.yml file


## [0.1.1] - 2015-10-18
### Added
- Capability to generate an opts.yml file to tweak aws-security-viz behavior.

### Removed
- Support for Ruby 1.9.3

## 0.1.0 - 2015-10-15
### Added
- Begin life as the gem [aws_security_viz](https://rubygems.org/gems/aws_security_viz)


[Unreleased]: https://github.com/anaynayak/aws-security-viz/compare/v0.1.3...HEAD
[0.1.3]: https://github.com/anaynayak/aws-security-viz/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/anaynayak/aws-security-viz/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/anaynayak/aws-security-viz/compare/v0.1.0...v0.1.1

