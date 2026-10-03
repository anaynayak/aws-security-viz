# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

### Added
- Documentation site at https://anaynayak.github.io/aws-security-viz/ (MkDocs Material, built strictly in CI and deployed from `main`); the README is now a short summary that links to it
- `SECURITY.md`: supported versions, private vulnerability reporting, scope, disclosure timeline, data handling and release verification
- Releases attest SLSA build provenance for the gem and the GHCR image, attach a CycloneDX SBOM and the provenance bundle (`.intoto.jsonl`) to the GitHub release, and create that release from this changelog
- Reproducible gem builds: `script/build-reproducible` normalises file permissions and sets `SOURCE_DATE_EPOCH`; CI builds the gem twice under different umask, timezone and directory and compares checksums
- CodeQL scanning for Ruby and GitHub Actions workflows, and an OpenSSF Scorecard workflow with a README badge
- CI builds and smoke-tests the Docker image on every pull request

### Changed
- The Docker base image is pinned by digest
- `--obfuscate` help text lists everything it hashes

### Fixed
- With `--obfuscate`, the warnings for skipped regions and for `--show-unused` without `ec2:DescribeNetworkInterfaces` printed the raw region name

## [1.0.0] - 2026-10-03
This release also covers the 0.3.0 work, which was never tagged or published.

### Breaking changes
- Ruby 3.3 or newer is required (it was 3.0 or newer in 0.2.4)
- The default output is now `aws-security-viz.html`, a self-contained page, instead of `aws-security-viz.png`. The output format is inferred from the -f/--output extension (.html, .json, .mmd, .dot/.gv, or an image such as .png/.svg). Image output still needs the Graphviz `dot` binary
- The old html viewers and the navigator renderer are removed, along with `--serve`
- There is no default region (it used to be us-east-1); the region comes from the AWS SDK credential/config chain (AWS_REGION, profile, ...) or -r, and a missing region fails with an error
- --profile no longer defaults to AWS_PROFILE, so explicit access keys are kept
- Node ids in JSON output are now security group ids; names are labels, and groups are clustered by VPC (and by region when several are queried)
- Edges are blue for ingress and red for egress; the per-group colour palette is gone and `--color` is ignored
- All library code is under the `AwsSecurityViz` namespace and moved to `lib/aws_security_viz/`; the top-level `VisualizeAws`, `Renderer`, `Ec2Provider` and similar constants no longer exist. Use the `aws_security_viz` executable, or `AwsSecurityViz::CLI`
- Obfuscation hashes are shorter (10 hex characters)
- Runtime dependencies are now only `aws-sdk-ec2` (>= 1.400, no upper cap) and `rexml`. `graphviz`, `rgl`, `optimist`, `webrick` and `organic_hash` are gone

### Deprecated
- --renderer: still works but prints a warning; use the -f extension instead. `--renderer navigator` now writes the html viewer
- --color: ignored, prints a warning

### Added
- Self-contained HTML viewer (`-f out.html`, the default): one file with Cytoscape.js 3.34.3 vendored and the graph data inlined, a Content-Security-Policy, no CDN or server, works from `file://`
- Mermaid flowchart output (`-f out.mmd`), with a warning when the diagram exceeds Mermaid's default edge or text limits
- Multi-region support: `--region us-east-1,eu-west-1` or `--all-regions` (needs `ec2:DescribeRegions`); regions that fail with an authorisation error are skipped with a warning
- Risky ingress highlighting: 0.0.0.0/0 or ::/0 reaching a sensitive port (22, 3389, 3306, 5432, 1433, 6379, 9200, 27017, configurable with `risky_ports` in opts.yml) or allowing all traffic is drawn distinctly and flagged `risky` in JSON and HTML output. --fail-on-risk exits 2 when any is found
- --show-unused marks security groups with no attached network interface (dashed grey in DOT, `unused` class in Mermaid, `unused: true` in JSON and HTML output); it needs `ec2:DescribeNetworkInterfaces` and is ignored with --source-file
- Rule descriptions are kept: JSON edges carry a `descriptions` list and DOT edges a `tooltip` (hashed under --obfuscate)
- --input and --output aliases for -o/--source-file and -f/--filename; `init` alias for `setup`
- --layout picks the Graphviz layout engine (overrides `format` in opts.yml; unknown engines are rejected)
- --debug (or DEBUG=true) for verbose output and stack traces, --obfuscate (or OBFUSCATE=true) to hash group names, ports and ids
- IPv6 ranges and prefix lists are drawn as rule peers
- --vpc-id is honoured for --source-file input
- Tag-triggered release workflow using RubyGems trusted publishing, which also pushes a multi-arch (amd64 and arm64) image to ghcr.io/anaynayak/aws-security-viz tagged `<version>`, `<major>.<minor>` and `latest`. The image is built from this source and runs as a non-root user

### Changed
- CLI moved into `AwsSecurityViz::CLI` on stdlib OptionParser
- Warnings, errors and debug output go to stderr through a Logger, keeping stdout clean
- Exit codes: 0 on success, 1 on error, 2 for --fail-on-risk, 130 on Ctrl-C
- Graph building uses a small adjacency-list graph and DOT is generated directly; Graphviz is only needed for image formats
- Rules that allow all traffic, ICMP, or a numeric protocol get readable labels, and all-traffic is labelled "all"
- Boolean environment variables (DEBUG, OBFUSCATE) are parsed as booleans
- Gemfile.lock is committed, the gemspec has no upper version caps, and CI tests Ruby 3.3, 3.4 and 4.0

### Removed
- The navigator renderer, the old view.html and navigator.html viewers, --serve and the webrick dependency
- The `rake docker:push` task and the per-push alpha gem workflow, replaced by the tag-triggered release workflow
- Support for Ruby older than 3.3

### Fixed
- Security groups sharing a name in different VPCs no longer collapse into one node
- Several rules between the same two groups are merged into a single edge with merged port labels
- DescribeSecurityGroups is paginated and the VPC filter is applied server-side
- Unknown renderers and layout engines are rejected, and errors are reported cleanly (exit 1, Ctrl-C exits 130)
- The test suite loads on Ruby 4.0

## [0.2.4] - 2023-06-10
- Matrix builds for Ruby v3.0 onwards only
- Remove support for Ruby v2.x

## [0.2.3] - 2021-07-03
### Added
- Support for Ruby v3
- Matrix builds for Ruby v2.5 to v3.0

## [0.2.2] - 2021-01-05
### Added
- --version option which prints aws-security-viz version
- Switchover to github actions from travis

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


[Unreleased]: https://github.com/anaynayak/aws-security-viz/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/anaynayak/aws-security-viz/compare/v0.2.4...v1.0.0
[0.1.3]: https://github.com/anaynayak/aws-security-viz/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/anaynayak/aws-security-viz/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/anaynayak/aws-security-viz/compare/v0.1.0...v0.1.1

