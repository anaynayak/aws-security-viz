---
description: Every aws-security-viz command line option, the opts.yml file, environment variables and exit codes.
---

# Configuration

## Command line options

Run `aws_security_viz --help` for the same list. Options are grouped here by purpose.

### Credentials and region

| Option | Meaning |
| --- | --- |
| `-a`, `--access-key=KEY` | AWS access key. |
| `-s`, `--secret-key=KEY` | AWS secret key. |
| `-e`, `--session-token=TOKEN` | AWS session token. |
| `-p`, `--profile=NAME` | Shared-config profile to use. |
| `-r`, `--region=REGION` | Region or comma-separated regions. Default: the SDK chain (`AWS_REGION` or the profile). |
| `--all-regions` | Query every region returned by `DescribeRegions`. |

### Input

| Option | Meaning |
| --- | --- |
| `-o`, `--source-file`, `--input=FILE` | JSON file from `aws ec2 describe-security-groups` instead of the live API. |
| `-v`, `--vpc-id=ID` | Show one VPC. |
| `--show-unused` | Mark groups with no attached network interfaces. Needs `ec2:DescribeNetworkInterfaces`; ignored with `--source-file`. |
| `-c`, `--config=FILE` | Config file. Default: `opts.yml` in the current directory. |

### Output

| Option | Meaning |
| --- | --- |
| `-f`, `--filename`, `--output=FILE` | Output file. The extension picks the format. Default: `aws-security-viz.html`. |
| `-y`, `--layout=ENGINE` | Graphviz layout engine: `dot`, `neato`, `sfdp`, `fdp`, `twopi` or `circo`. Overrides `:format:` in `opts.yml`. |
| `-n`, `--renderer=NAME` | Deprecated. Use the `-f` extension. |
| `-l`, `--[no-]color` | Deprecated and ignored. |

### Filtering and checks

| Option | Meaning |
| --- | --- |
| `-u`, `--source-filter=FILTER` | Keep only what is reachable from this group (id or name). |
| `-t`, `--target-filter=FILTER` | Keep only routes that arrive at this group (id or name). |
| `--fail-on-risk` | Exit 2 when `0.0.0.0/0` or `::/0` can reach a sensitive port. The output is still written. |

See [Filtering and risk checks](filtering-and-risk-checks.md).

### Diagnostics

| Option | Meaning |
| --- | --- |
| `-d`, `--[no-]debug` | Verbose output and stack traces (or `DEBUG=true`). |
| `-b`, `--[no-]obfuscate` | Hash ids, group names, VPC ids, regions, ports and rule descriptions in all output (or `OBFUSCATE=true`). |
| `-i`, `--version` | Print the version and exit. |
| `-h`, `--help` | Show the option list. |

The commands `setup` and `init` (an alias) write a sample `opts.yml`.

## Environment variables

| Variable | Effect |
| --- | --- |
| `AWS_REGION`, `AWS_PROFILE`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` | Read by the AWS SDK; see [Credentials and IAM](credentials-and-iam.md). |
| `DEBUG` | `true`, `1`, `yes` or `on` enable debug output; `false`, `0`, `no` or `off` disable it. `--[no-]debug` wins. |
| `OBFUSCATE` | Same values as `DEBUG`. `--[no-]obfuscate` wins. |

Any other value for `DEBUG` or `OBFUSCATE` is an error.

## opts.yml

`opts.yml` in the current directory is loaded automatically when it exists; `-c` points at another file. Generate a
sample with:

```
aws_security_viz setup
```

```
opts.yml created in current directory.
```

The file is YAML with symbol keys:

```yaml
---
:format: dot
:egress: true
:risky_ports: [22, 3389, 3306, 5432, 1433, 6379, 9200, 27017]
:exclude:
  - ^amazon-
:groups:
  '8.8.8.8/32': Partner
```

| Key | Meaning |
| --- | --- |
| `:format:` | Graphviz layout engine (`dot`, `neato`, `sfdp`, `fdp`, `twopi`, `circo`), not an output format. `--layout` overrides it. |
| `:egress:` | Draw egress rules. Default `true`; set `false` to draw ingress only. |
| `:risky_ports:` | Ports flagged when open to `0.0.0.0/0` or `::/0`. Default: 22, 3389, 3306, 5432, 1433, 6379, 9200, 27017. Rules that allow all traffic are always flagged. An entry that is not a port number from 1 to 65535 is an error. |
| `:exclude:` | List of unanchored regular expressions. A group or rule peer whose name matches is dropped. |
| `:groups:` | Maps a CIDR, group id or group name to a label. All peers with the same label collapse into one node. |

With the example above the sample input draws `8.8.8.8/32` as `Partner` and drops `amazon-elb-sg`.

The sample written by `setup` ships placeholder `:groups:` entries (`x.x.x.x/0`) that are not valid CIDRs; replace or
delete them.

## Obfuscation

`--obfuscate` replaces node ids, group names, VPC ids, regions, group-id labels, port labels and rule description text
with the first 10 hex characters of their unsalted SHA-256, in every output format and in `--debug` logs:

```
aws_security_viz -o security_groups.json --obfuscate -f viz.mmd
```

The graph shape, edge directions and the risky and unused flags remain visible, and small value spaces such as port
numbers can be recovered by hashing candidates. See [Security](security.md#4-data-handling) before sharing a file.

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | Success. |
| 1 | Error: bad option, missing region or credentials, AWS error, unreadable input, unknown output format. |
| 2 | `--fail-on-risk` and at least one risky edge. The output is still written. |
| 130 | Interrupted (Ctrl-C). |

## Output streams

Warnings, errors, debug output and the `no risky public ingress found` line go to stderr. Only `--help`, `--version`
and the `setup` message go to stdout, so redirecting stdout never hides a diagnostic.
