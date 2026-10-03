aws-security-viz -- A tool to visualize aws security groups
============================================================
[![Build Status](https://github.com/anaynayak/aws-security-viz/workflows/Ruby/badge.svg)](https://github.com/anaynayak/aws-security-viz/actions?query=workflow%3ARuby)
[![License](https://img.shields.io/github/license/anaynayak/aws-security-viz.svg?maxAge=2592000)]()
[![Docker image](https://img.shields.io/badge/ghcr.io-aws--security--viz-blue)](https://github.com/anaynayak/aws-security-viz/pkgs/container/aws-security-viz)
![Gem Downloads (for latest version)](https://img.shields.io/gem/dtv/aws_security_viz)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/anaynayak/aws-security-viz/badge)](https://scorecard.dev/viewer/?uri=github.com/anaynayak/aws-security-viz)

## DESCRIPTION
  Need a quick way to visualize your current aws/amazon ec2 security group configuration? aws-security-viz does just that based on the EC2 security group ingress configuration.

![](https://github.com/anaynayak/aws-security-viz/raw/main/images/sample.png)

## FEATURES

* Reads the live AWS API, or the JSON from `aws ec2 describe-security-groups`.
* Output formats: a self-contained HTML viewer, JSON, Mermaid, DOT, and any image format Graphviz supports (png, svg, pdf and others).
* One region, several regions, or all regions in a single graph; groups are clustered by region and VPC.
* Risky public ingress (`0.0.0.0/0` or `::/0` on a sensitive port) is drawn as a dashed crimson edge, and `--fail-on-risk` turns it into a failing exit code for CI.
* `--show-unused` marks security groups that no network interface uses.

## INSTALLATION

From RubyGems:

```
  $ gem install aws_security_viz
  $ aws_security_viz --help
```

Or run the published image, which has Ruby and Graphviz built in (see [Docker usage](#docker-usage)):

```
  $ docker pull ghcr.io/anaynayak/aws-security-viz:<version>
```

## DEPENDENCIES

* Ruby 3.3 or newer.
* Graphviz (`brew install graphviz`), only for image formats (png, svg, pdf and so on). The HTML, JSON, Mermaid and DOT outputs do not need it.

## USAGE

The output format follows the extension of `-f/--output`: `.html` (the default is `aws-security-viz.html`), `.json`, `.mmd`, `.dot` or `.gv`, or an image such as `.png` or `.svg`. The older `--renderer` flag is deprecated; it still works and prints a warning.

To generate a graph from an existing security_groups.json (created using aws-cli, see [Debugging](#debugging))

```
  $ aws_security_viz -o security_groups.json -f viz.svg
```

To query AWS directly with a shared-config profile (`--profile` also works with SSO profiles after `aws sso login --profile <profile_name>`)

```
  $ aws_security_viz --profile <profile_name> --region us-west-1 -f viz.html
```

The credentials and region otherwise come from the standard AWS SDK chain (`AWS_PROFILE`, `AWS_REGION`, environment variables, SSO, instance roles). There is no built-in default region, so a missing region fails with `MissingRegionError`.

With [aws-vault](https://github.com/99designs/aws-vault/) and short lived temporary credentials

```
  $ aws-vault exec <profile_name> -- aws_security_viz --region us-west-1 -f viz.html
```

With explicit keys (`-a/--access-key`, `-s/--secret-key`, `-e/--session-token`). Prefer a profile, aws-vault or SSO, because keys passed on the command line end up in your shell history.

### Regions

With several regions (`--region us-east-1,eu-west-1` or `--all-regions`) nodes are grouped by region, then VPC. With `--all-regions`, `-r` (first name if a list) is only the region used to call `DescribeRegions`. A region that fails with `UnauthorizedOperation`, `AuthFailure` or `OptInRequired` is skipped with a warning; the run fails only if every region fails. The JSON and HTML outputs carry the region on each node. `--region` and `--all-regions` are ignored (with a warning) when `--source-file` is used.

### Risky ingress

Ingress from `0.0.0.0/0` or `::/0` on a sensitive port (22, 3389, 3306, 5432, 1433, 6379, 9200, 27017) or on all traffic is flagged on stderr and drawn as a dashed crimson edge. Change the ports with `risky_ports` in opts.yml. `--fail-on-risk` exits with status 2 when any such edge exists; the output file is still written.

## DOCKER USAGE

Run aws-security-viz from the published image instead of installing Ruby and Graphviz. Releases push a multi-arch (amd64 and arm64) image to `ghcr.io/anaynayak/aws-security-viz`, tagged `<version>` (for example `1.0.0`), `<major>.<minor>` (for example `1.0`) and `latest` (stable releases only). Pin a version tag for reproducible runs. The image's entrypoint is `bundle exec aws_security_viz`, so everything after the image name is a normal CLI argument. It runs as a non-root user with `/work` as the working directory; mount a local directory there to get the output files.

1. With aws-vault (recommended):

```
aws-vault exec <profile_name> -- docker run --rm --user $(id -u):$(id -g) \
  -e AWS_REGION -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_SESSION_TOKEN -e AWS_SECURITY_TOKEN \
  -v "$(pwd)/aws-viz:/work" ghcr.io/anaynayak/aws-security-viz:<version> -f /work/aws.svg
```

2. With an SSO profile, mounting your AWS config (run `aws sso login --profile <profile_name>` first):

```
docker run --rm --user $(id -u):$(id -g) -e HOME=/home/viz -e AWS_PROFILE=<profile_name> -e AWS_REGION \
  -v "$HOME/.aws:/home/viz/.aws" -v "$(pwd)/aws-viz:/work" \
  ghcr.io/anaynayak/aws-security-viz:<version> -f /work/aws.svg
```

3. With AWS credentials passed as parameters:

```
docker run --rm --user $(id -u):$(id -g) -v "$(pwd)/aws-viz:/work" ghcr.io/anaynayak/aws-security-viz:<version> \
  -a REPLACE_AWS_ACCESS_KEY_ID -s REPLACE_SECRET -r REPLACE_REGION -f /work/aws.svg
```

4. To build the image from a checkout instead: `docker build -t sec-viz .` and use `sec-viz` in place of the ghcr.io name.

Notes:
* `-v "$(pwd)/aws-viz:/work"` is the local directory where output is written. Create it first (`mkdir aws-viz`).
* `--user $(id -u):$(id -g)` matters on Linux: bind mounts keep the host's ownership, so the container's non-root
  user cannot write to a directory owned by you and the run fails with "Permission denied". Running as your own
  uid/gid fixes that and leaves the output files owned by you. Docker Desktop on macOS does not need it.
* `--rm` removes the container after the run.

You can also use any other option from the [help](#help) below.

### Help

```
$ aws_security_viz --help
Usage: aws_security_viz [options] [setup|init]
    -a, --access-key=KEY             AWS access key
    -s, --secret-key=KEY             AWS secret key
    -e, --session-token=TOKEN        AWS session token
    -r, --region=REGION              AWS region(s) to query, comma-separated (default: SDK chain, e.g. AWS_REGION or profile)
        --all-regions                Query every region returned by DescribeRegions
    -p, --profile=NAME               AWS shared-config profile to use (AWS_PROFILE is read by the SDK)
    -v, --vpc-id=ID                  AWS VPC id to show
    -o, --source-file, --input=FILE  JSON source file containing security groups
    -f, --filename, --output=FILE    Output file; the format follows the extension: .html, .json, .mmd, .dot/.gv or an image such as .png/.svg (default: aws-security-viz.html)
    -c, --config=FILE                Config file (opts.yml)
    -l, --[no-]color                 Deprecated, ignored: edges are blue for ingress and red for egress, risky public ingress is dashed crimson
    -n, --renderer=NAME              Deprecated, use the -f extension instead: renderer (graphviz|json|html|mermaid)
    -y, --layout=ENGINE              Graphviz layout engine (dot|neato|sfdp|fdp|twopi|circo); overrides opts.yml format
    -d, --[no-]debug                 Verbose output and stack traces (or DEBUG=true)
    -b, --[no-]obfuscate             Hash group names and ports (or OBFUSCATE=true)
    -u, --source-filter=FILTER       Source filter
    -t, --target-filter=FILTER       Target filter
        --show-unused                Mark groups with no attached network interfaces (needs ec2:DescribeNetworkInterfaces; ignored with --source-file)
        --fail-on-risk               Exit 2 when 0.0.0.0/0 or ::/0 can reach a sensitive port (the output is still written)
    -i, --version                    Print version and exit
    -h, --help                       Show this message
```

#### Configuration

aws-security-viz only uses the `ec2:DescribeSecurityGroups` api, so a minimal IAM policy which grants only that action should be enough. Two flags call more:

1. `--all-regions` calls `ec2:DescribeRegions`.
2. `--show-unused` calls `ec2:DescribeNetworkInterfaces` (paginated, per region). Without the permission the run still succeeds and logs a warning, but no groups are marked unused.

Add an action to the policy only if you use its flag.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeRegions",
                "ec2:DescribeNetworkInterfaces"
            ],
            "Resource": "*"
        }
    ]
}
```

#### Advanced configuration

You can generate a configuration file using the following command (`init` is an alias for `setup`):
```
  $ aws_security_viz setup [-c opts.yml]
```

The opts.yml file lets you define the following options:

* Grouping of CIDR ips
* Define exclusion patterns
* Change graphviz format (neato, dot, sfdp etc)
* Change the ports flagged as risky (`risky_ports`)

## DEBUGGING

To generate the graph with debug statements, pass `--debug` (or set `DEBUG=true`). Debug output goes to stderr.

```
$ aws_security_viz --debug --profile <profile_name> --region us-west-1 -f viz.svg
```

If it doesn't indicate the problem, please open an issue on [GitHub](https://github.com/anaynayak/aws-security-viz/issues) and attach the security group JSON. Obfuscate it first with `--obfuscate` (or `OBFUSCATE=true`), which hashes group names and ports in the output:

```
$ aws_security_viz --debug --obfuscate --profile <profile_name> --region us-west-1 -f viz.json
```

Execute the following command to generate the JSON input for `--source-file`. You will need [aws-cli](https://github.com/aws/aws-cli) to execute the command

`aws ec2 describe-security-groups > security_groups.json`


## EXAMPLES

#### Graphviz export

![](https://github.com/anaynayak/aws-security-viz/raw/main/images/sample.png)

Generated from `spec/integration/dummy.json` with `aws_security_viz -o spec/integration/dummy.json -f images/sample.png`.

#### HTML viewer (useful with very large number of nodes)

`aws_security_viz --profile <profile_name> --region us-west-1 -f aws.html` writes one self-contained file with the graph data inlined. Open it from disk in a browser; no web server is needed.

## Additional examples

#### Generate `aws-security-viz.png` image for `us-west-1` region

```
  $ aws_security_viz --region us-west-1 -f aws-security-viz.png
```

#### Generate visualization for `us-west-1` with target filter as `sec-group-1`. This will display all routes through which we can arrive at `sec-group-1`

```
  $ aws_security_viz --region us-west-1 -f aws.html --target-filter=sec-group-1
```

#### Generate visualization for `us-west-1` restricted to vpc-id `vpc-12345`
```
  $ aws_security_viz --region us-west-1 -f aws.html --vpc-id=vpc-12345
```

#### Fail a CI job when a sensitive port is open to the internet
```
  $ aws_security_viz --all-regions --fail-on-risk -f aws.json
```

#### Generate a Mermaid diagram
```
  $ aws_security_viz --region us-west-1 -f aws.mmd
```
