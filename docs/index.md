---
description: Visualise AWS security groups, see which groups can reach which, and find ingress open to the internet, in one file you can open offline.
---

# aws-security-viz

[![Build Status](https://github.com/anaynayak/aws-security-viz/workflows/Ruby/badge.svg)](https://github.com/anaynayak/aws-security-viz/actions?query=workflow%3ARuby)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/anaynayak/aws-security-viz/badge)](https://scorecard.dev/viewer/?uri=github.com/anaynayak/aws-security-viz)
[![Gem Version](https://img.shields.io/gem/v/aws_security_viz)](https://rubygems.org/gems/aws_security_viz)
[![Docker image](https://img.shields.io/badge/ghcr.io-aws--security--viz-blue)](https://github.com/anaynayak/aws-security-viz/pkgs/container/aws-security-viz)
[![License](https://img.shields.io/github/license/anaynayak/aws-security-viz.svg)](https://github.com/anaynayak/aws-security-viz/blob/main/LICENSE.md)

See which security groups can reach which, and which are open to the internet, in one file you can open offline.

aws-security-viz reads the EC2 security group configuration from the AWS API, or from the JSON written by
`aws ec2 describe-security-groups`, and draws it as a graph.

![Security group graph rendered with Graphviz: a risky 0.0.0.0/0 edge into the app group](assets/sample.png)

<div class="grid cards" markdown>

1. **HTML viewer.** One self-contained page with search, ingress and egress toggles and a details panel. Large graphs open with each VPC collapsed into one node, and a WebGL renderer takes over for very large ones. No server, no CDN. See [Outputs](outputs.md#html-viewer).
2. **Risky ingress highlighting.** `0.0.0.0/0` or `::/0` on a sensitive port is drawn as a dashed crimson edge, and `--fail-on-risk` turns it into a failing exit code. See [Filtering and risk checks](filtering-and-risk-checks.md).
3. **Runs anywhere.** Install the gem, or run the published container image with Ruby and Graphviz built in. See [Installation](installation.md).

</div>

## Try it

```
gem install aws_security_viz
aws_security_viz -o security_groups.json
```

The sample [security_groups.json](assets/security_groups.json) needs no AWS access. The command writes
`aws-security-viz.html`; open it in a browser. The [Quickstart](quickstart.md) covers live AWS access and Docker.

## Where to go next

1. [Quickstart](quickstart.md): first graph from a JSON file, live AWS or Docker.
2. [Configuration](configuration.md): every option, `opts.yml` and exit codes.
3. [Credentials and IAM](credentials-and-iam.md): how credentials are found and the minimal IAM policy.
4. [Security](security.md): what leaves your machine and how to verify a release.

aws-security-viz is MIT licensed. The HTML viewer inlines vendored copies of Cytoscape.js, cytoscape-fcose, cose-base and layout-base, which are also MIT licensed; their notices ship inside the gem under `lib/aws_security_viz/vendor/`.
