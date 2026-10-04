# aws-security-viz

[![Build Status](https://github.com/anaynayak/aws-security-viz/workflows/Ruby/badge.svg)](https://github.com/anaynayak/aws-security-viz/actions?query=workflow%3ARuby)
[![Gem Version](https://img.shields.io/gem/v/aws_security_viz)](https://rubygems.org/gems/aws_security_viz)
[![Gem Downloads](https://img.shields.io/gem/dtv/aws_security_viz)](https://rubygems.org/gems/aws_security_viz)
[![Docker image](https://img.shields.io/badge/ghcr.io-aws--security--viz-blue)](https://github.com/anaynayak/aws-security-viz/pkgs/container/aws-security-viz)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/anaynayak/aws-security-viz/badge)](https://scorecard.dev/viewer/?uri=github.com/anaynayak/aws-security-viz)
[![License](https://img.shields.io/github/license/anaynayak/aws-security-viz.svg)](LICENSE.md)

See which AWS security groups can reach which, and which are open to the internet. aws-security-viz reads the EC2
security group configuration from the AWS API, or from the JSON written by `aws ec2 describe-security-groups`, and draws
it as a graph.

![Security group graph](https://github.com/anaynayak/aws-security-viz/raw/main/images/sample.png)

1. Output formats: a self-contained HTML viewer (the default), JSON, Mermaid, DOT, and any image format Graphviz supports.
2. One region, several regions, or all regions in a single graph.
3. Risky public ingress (`0.0.0.0/0` or `::/0` on a sensitive port) is drawn as a dashed crimson edge, and
   `--fail-on-risk` turns it into exit status 2 for CI.

Documentation: https://anaynayak.github.io/aws-security-viz/

## Install

Ruby 3.3 or newer. Graphviz is needed only for image formats such as png and svg.

```
gem install aws_security_viz
```

Or run the published image, which has Ruby and Graphviz built in:

```
docker pull ghcr.io/anaynayak/aws-security-viz:<version>
```

## Example

```
aws ec2 describe-security-groups > security_groups.json
aws_security_viz -o security_groups.json -f viz.html
```

Open `viz.html` in a browser. To query AWS directly, use `--profile <profile_name> --region us-west-1` in place of `-o`.

## Learn more

1. [Quickstart](https://anaynayak.github.io/aws-security-viz/quickstart/)
2. [Outputs and the HTML viewer](https://anaynayak.github.io/aws-security-viz/outputs/)
3. [Configuration, opts.yml and exit codes](https://anaynayak.github.io/aws-security-viz/configuration/)
4. [Credentials and IAM](https://anaynayak.github.io/aws-security-viz/credentials-and-iam/)
5. [Filtering and risk checks, including CI](https://anaynayak.github.io/aws-security-viz/filtering-and-risk-checks/)
6. [Troubleshooting](https://anaynayak.github.io/aws-security-viz/troubleshooting/)

Also: [SECURITY.md](SECURITY.md), [CHANGELOG.md](CHANGELOG.md), [CONTRIBUTING.md](CONTRIBUTING.md) and
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## LICENSE

MIT, see [LICENSE.md](LICENSE.md). The HTML viewer inlines vendored copies of Cytoscape.js, cytoscape-fcose, cose-base and layout-base, which are also MIT licensed; their notices are under [lib/aws_security_viz/vendor/](lib/aws_security_viz/vendor/) and ship inside the gem.
