aws-security-viz -- A tool to visualize aws security groups
============================================================
[![Build Status](https://github.com/anaynayak/aws-security-viz/workflows/Ruby/badge.svg)](https://github.com/anaynayak/aws-security-viz/actions?query=workflow%3ARuby)
[![License](https://img.shields.io/github/license/anaynayak/aws-security-viz.svg?maxAge=2592000)]()
[![Docker image](https://img.shields.io/badge/ghcr.io-aws--security--viz-blue)](https://github.com/anaynayak/aws-security-viz/pkgs/container/aws-security-viz)
[![Dependency Status](https://img.shields.io/librariesio/github/anaynayak/aws-security-viz.png?maxAge=259200)](https://libraries.io/github/anaynayak/aws-security-viz)
![Gem Downloads (for latest version)](https://img.shields.io/gem/dtv/aws_security_viz)


## DESCRIPTION
  Need a quick way to visualize your current aws/amazon ec2 security group configuration? aws-security-viz does just that based on the EC2 security group ingress configuration.

## FEATURES

* Output to any of the formats that Graphviz supports.
* EC2 classic and VPC security groups

## INSTALLATION
```
  $ gem install aws_security_viz
  $ aws_security_viz --help
```

## DEPENDENCIES

* graphviz `brew install graphviz`

## USAGE (See Examples section below for more)

To generate the graph directly using AWS keys

```
  $ aws_security_viz -a your_aws_key -s your_aws_secret_key -f viz.svg --color=true
```

To generate the graph using an existing security_groups.json (created using aws-cli)

```
  $ aws_security_viz -o data/security_groups.json -f viz.svg --color
```

To generate a web view

```
  $ aws_security_viz -a your_aws_key -s your_aws_secret_key -f aws.json --renderer navigator
```

* Generates two files: aws.json and navigator.html.
* The json file name needs to be passed in as a html fragment identifier.
* The generated graph can be viewed in a webserver e.g. http://localhost:3000/navigator.html#aws.json by using `ruby -run -e httpd -- -p 3000`

## DOCKER USAGE

Run aws-security-viz from the published image instead of installing Ruby and Graphviz. The image's entrypoint is
`aws_security_viz`, so everything after the image name is a normal CLI argument. It runs as a non-root user with
`/work` as the working directory; mount a local directory there to get the output files.

1. With aws-vault (recommended):

```
aws-vault exec <profile_name> -- docker run --rm --user $(id -u):$(id -g) \
  -e AWS_REGION -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_SESSION_TOKEN -e AWS_SECURITY_TOKEN \
  -v "$(pwd)/aws-viz:/work" ghcr.io/anaynayak/aws-security-viz -f /work/aws.svg
```

2. With AWS credentials passed as parameters:

```
docker run --rm --user $(id -u):$(id -g) -v "$(pwd)/aws-viz:/work" ghcr.io/anaynayak/aws-security-viz \
  -a REPLACE_AWS_ACCESS_KEY_ID -s REPLACE_SECRET -r REPLACE_REGION -f /work/aws.svg
```

3. To build the image from a checkout instead: `docker build -t sec-viz .` and use `sec-viz` in place of the ghcr.io name.

The region comes from `-r/--region`, or otherwise from the AWS SDK chain (`AWS_REGION`, a profile); there is no built-in default, so a missing region fails with `MissingRegionError`.

Notes:
* `-v "$(pwd)/aws-viz:/work"` is the local directory where output is written. Create it first (`mkdir aws-viz`).
* `--user $(id -u):$(id -g)` matters on Linux: bind mounts keep the host's ownership, so the container's non-root
  user cannot write to a directory owned by you and the run fails with "Permission denied". Running as your own
  uid/gid fixes that and leaves the output files owned by you. Docker Desktop on macOS does not need it.
* `--rm` removes the container after the run.

You can also use other parameters as specified in [usage](#USAGE)

### Help

```
$ aws_security_viz --help
Options:
  -a, --access-key=<s>       AWS access key
  -s, --secret-key=<s>       AWS secret key
  -e, --session-token=<s>    AWS session token
  -r, --region=<s>           AWS region to query (default: SDK chain, e.g.
                             AWS_REGION or profile)
  -p, --profile=<s>          AWS shared-config profile to use (AWS_PROFILE is
                             read by the SDK)
  -v, --vpc-id=<s>           AWS VPC id to show
  -o, --source-file=<s>      JSON source file containing security groups
  -f, --filename=<s>         Output file name (default: aws-security-viz.png,
                             or .json for json/navigator)
  -c, --config=<s>           Config file (opts.yml) (default: opts.yml)
  -l, --color                Colored node edges
  -n, --renderer=<s>         Renderer (graphviz|json|navigator) (default:
                             graphviz)
  -y, --layout=<s>           Graphviz layout engine
                             (dot|neato|sfdp|fdp|twopi|circo); overrides
                             opts.yml format
  -d, --debug                Verbose output and stack traces (or DEBUG=true)
  -b, --obfuscate            Hash group names and ports (or OBFUSCATE=true)
  -u, --source-filter=<s>    Source filter
  -t, --target-filter=<s>    Target filter
  --serve=<i>                Serve a HTTP server
  -i, --version              Print version and exit
  -h, --help                 Show this message
```

#### Configuration 

aws-security-viz only uses the `ec2:DescribeSecurityGroups` api so a minimal IAM policy which grants only `ec2:DescribeSecurityGroups` access should be enough.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "ec2:DescribeSecurityGroups",
            "Resource": "*"
        }
    ]
}
```

Alternatively you can use [aws-vault](https://github.com/99designs/aws-vault/) and run it using short lived temporary credentials.

`$ aws-vault exec <profile> -- aws_security_viz -f aws.json --renderer navigator --serve 9091`

#### Advanced configuration

You can generate a configuration file using the following command:
```
  $ aws_security_viz setup [-c opts.yml]
```

The opts.yml file lets you define the following options:

* Grouping of CIDR ips
* Define exclusion patterns
* Change graphviz format (neato, dot, sfdp etc)

## DEBUGGING

To generate the graph with debug statements, execute the following command

```
$ DEBUG=true aws_security_viz -a your_aws_key -s your_aws_secret_key -f viz.svg
```

If it doesn't indicate the problem, please share the generated json file with me @ whynospam-awsviz@yahoo.co.in

You can send me an obfuscated version using the following command:

```
$ DEBUG=true OBFUSCATE=true aws_security_viz -a your_aws_key -s your_aws_secret_key -f viz.svg
```

Execute the following command to generate the json. You will need [aws-cli](https://github.com/aws/aws-cli) to execute the command

`aws ec2 describe-security-groups`


## EXAMPLES

#### Graphviz export

![](https://github.com/anaynayak/aws-security-viz/raw/main/images/sample.png)

#### Navigator view (useful with very large number of nodes)
Via navigator renderer `aws_security_viz -a your_aws_key -s your_aws_secret_key -f aws.json --renderer navigator`
![](https://user-images.githubusercontent.com/416211/51426583-bb5e0180-1c12-11e9-903b-7b2a2d354ede.png)

#### JSON view
Via json renderer `aws_security_viz -a your_aws_key -s your_aws_secret_key -f aws.json --renderer json`
![](https://cloud.githubusercontent.com/assets/416211/11912582/0e66cdbc-a669-11e5-82ab-1e26e3c6949b.png)

## Additional examples

#### Generate `aws-security-viz.png` image for `us-west-1` region

```
  $ aws_security_viz --region us-west-1 -f aws-security-viz.png
```

#### Generate visualization for `us-west-1` with target filter as `sec-group-1`. This will display all routes through which we can arrive at `sec-group-1`

```
  $ aws_security_viz --region us-west-1 --target-filter=sec-group-1
```

#### Generate visualization for `us-west-1` restricted to vpc-id `vpc-12345`
```
  $ aws_security_viz --region us-west-1 --vpc-id=vpc-12345
```

#### Generate visualization for `us-west-1` restricted to vpc-id `vpc-12345`
```
  $ aws_security_viz --region us-west-1 --vpc-id=vpc-12345
```

#### Serve webserver for the navigator view at port 3000
```
  $ aws_security_viz -a your_aws_key -s your_aws_secret_key -f aws.json --renderer navigator --serve 3000
```
The browser link to the view is printed on the CLI
