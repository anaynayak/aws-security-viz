---
description: Filter the graph by VPC, source or target group and exclusion patterns, and understand exactly what the risky ingress check flags.
---

# Filtering and risk checks

## VPC filter

`-v/--vpc-id=ID` keeps one VPC. With live AWS access the filter is applied server-side in `DescribeSecurityGroups`; with
`--source-file` it is applied to the file's contents.

```
aws_security_viz --region us-west-1 -f aws.html --vpc-id=vpc-12345
```

## Source and target filters

`-u/--source-filter` and `-t/--target-filter` take a group id (`sg-...`) or a group name. Both are matched after the
graph is built.

1. `-t <group>` keeps every route that can arrive at the group.
2. `-u <group>` keeps everything reachable from the group.
3. Together they keep only groups on a path from the source to the target.

```
aws_security_viz -o security_groups.json -t sg-appgrp -f viz.json
aws_security_viz -o security_groups.json -t app -f viz.json
```

A filter that matches nothing is an error, and a name shared by several groups is an error that asks for a group id:

```
[ERROR] no group or peer matches 'nosuch'
```

Peers such as CIDR ranges are nodes too, so `-u 0.0.0.0/0` is valid.

## Exclusion patterns

`:exclude:` in `opts.yml` takes regular expressions, matched without anchors against group names and against the names
of rule peers. Matching groups and peers are dropped from the graph. See [Configuration](configuration.md#optsyml).

## Several regions

`--region us-east-1,eu-west-1` or `--all-regions` queries more than one region. Nodes are grouped by region, then VPC. A
region that fails with `UnauthorizedOperation`, `AuthFailure` or `OptInRequired` is skipped with a warning; the run
fails only if every region fails. `--region` and `--all-regions` are ignored, with a warning, when `--source-file` is
used.

## What counts as risky

An edge is risky when all of these hold:

1. It is an ingress rule. Egress is never risky.
2. The peer is `0.0.0.0/0` (IPv4) or `::/0` (IPv6).
3. The rule is either all traffic (protocol `-1`), or protocol TCP (`tcp` or `6`) whose port range includes a risky
   port.

The default risky ports are 22, 3389, 3306, 5432, 1433, 6379, 9200 and 27017. Change them with `:risky_ports:` in
`opts.yml`; an entry that is not a port number from 1 to 65535 is an error.

The check is narrower than "an open port". UDP and ICMP rules, ranges that exclude every risky port, and rules open to
a specific CIDR are not flagged. It runs on the real rule, before CIDR group mapping, merging and obfuscation, so a
renamed peer or a merged label cannot hide a risky rule.

Risky edges are drawn as thick dashed crimson edges, flagged `risky` in JSON and HTML data, and counted on stderr:

```
[WARN] 1 risky edge: public ingress (0.0.0.0/0 or ::/0) on a sensitive port or all traffic
```

With none, the tool prints `[INFO] no risky public ingress found`.

## Failing a CI job

`--fail-on-risk` exits with status 2 when at least one risky edge exists. The output file is still written, so a job can
upload it as an artifact. Exit status 1 means the tool itself failed, so a pipeline can tell "risk found" from "tool
failed". See [exit codes](configuration.md#exit-codes).

```
aws_security_viz -o security_groups.json --fail-on-risk -f viz.json
echo $?
```

```
[WARN] 1 risky edge: public ingress (0.0.0.0/0 or ::/0) on a sensitive port or all traffic
2
```

Filters change the result. `--fail-on-risk` counts only the risky edges that survive filtering, so restricting the graph
with `-u`, `-t` or `--vpc-id` can turn a failing run into a passing one:

```
aws_security_viz -o security_groups.json --fail-on-risk -u app -f viz.json
echo $?
```

```
[INFO] no risky public ingress found
0
```

### GitHub Actions example

This job assumes an IAM role through OIDC (no stored keys), runs the published image, and uploads the HTML report even
when the check fails. Replace `<account_id>`, `<role_name>` and `<version>`. Pin the actions to commit SHAs in your own
workflows.

```yaml
name: security-groups
on:
  schedule:
    - cron: "0 6 * * 1"
  workflow_dispatch:

permissions:
  contents: read
  id-token: write

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::<account_id>:role/<role_name>
          aws-region: us-west-1
      - name: Check for public ingress
        run: |
          mkdir out
          docker run --rm --user "$(id -u):$(id -g)" \
            -e AWS_REGION -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_SESSION_TOKEN \
            -v "$PWD/out:/work" ghcr.io/anaynayak/aws-security-viz:<version> \
            --all-regions --fail-on-risk -f /work/security-groups.html
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: security-groups
          path: out/security-groups.html
```

The role needs the actions in [Credentials and IAM](credentials-and-iam.md#minimal-iam-policy).
