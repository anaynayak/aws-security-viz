# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]
### Added
- CHANGELOG.md

### Fixed
- Issue with vagrant up not working due to older bundler version and missing dependencies

## [0.1.3] - 2015-03-20
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

