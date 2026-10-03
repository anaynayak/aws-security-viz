---
description: Short answers about aws-security-viz - AWS changes, empty output, network access, Terraform, graph size and Ruby versions.
---

# FAQ

## Does it change anything in AWS?

No. It makes read-only EC2 calls: `DescribeSecurityGroups` always, `DescribeRegions` with `--all-regions` and
`DescribeNetworkInterfaces` with `--show-unused`. See [Credentials and IAM](credentials-and-iam.md).

## Why is the output empty?

A `-u`, `-t`, `--vpc-id` or `:exclude:` setting removed every node, or the region has no security groups. See
[Troubleshooting](troubleshooting.md).

## Does the HTML report phone home?

No. The file inlines Cytoscape.js and the data, has a Content-Security-Policy that blocks network access, and opens
offline from `file://`. See [Security](security.md#4-data-handling).

## Does it read Terraform or CloudFormation?

No. It reads the live EC2 API or the JSON from `aws ec2 describe-security-groups`, so it shows what is deployed.

## How large a graph is practical?

The HTML viewer is the format for large accounts. Mermaid output warns above 500 edges or 50,000 characters, and
Graphviz layouts slow down as the node count grows; try `--layout sfdp` for big graphs.

## What does it show that the AWS console does not?

All groups and their relationships in one graph, clustered by region and VPC, with risky public ingress highlighted and
a CI exit code for it.

## Which Ruby versions are supported?

Ruby 3.3 and newer; CI tests 3.3, 3.4 and 4.0. The container image bundles its own Ruby.

## Can I share the output?

Treat it as sensitive: it names groups, ids and CIDR ranges. Use `--obfuscate` to hash them first, and read what that
does and does not hide in [Security](security.md#4-data-handling).
