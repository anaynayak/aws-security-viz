aws-security-viz -- A tool to visualize aws security groups
============================================================
[![Build Status](https://secure.travis-ci.org/anaynayak/aws-security-viz.png)](http://travis-ci.org/anaynayak/aws-security-viz)
[![Gem Version](https://badge.fury.io/rb/aws_security_viz.svg)](https://badge.fury.io/rb/aws_security_viz)
[![License](https://img.shields.io/github/license/anaynayak/aws-security-viz.svg?maxAge=2592000)]()
[![Code Climate](https://codeclimate.com/github/anaynayak/aws-security-viz.png)](https://codeclimate.com/github/anaynayak/aws-security-viz)
[![Docker image](https://images.microbadger.com/badges/image/anay/aws-security-viz.svg)](https://microbadger.com/images/anay/aws-security-viz)
[![Dependency Status](https://img.shields.io/librariesio/github/anaynayak/aws-security-viz.png?maxAge=259200)](https://libraries.io/github/anaynayak/aws-security-viz)

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

If you don't want to install the dependencies and ruby libs you can execute aws-security-viz inside a docker container. To do so, follow these steps:

1. Clone this repository, open it in a console.
2. Build the docker container: `docker build -t sec-viz .`

3.a With aws-vault (Recommended):

```aws-vault exec tldev -- docker run -i -e AWS_REGION -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_SESSION_TOKEN -e AWS_SECURITY_TOKEN --rm -t -p 3000:3000 -v (pwd)/aws-viz:/aws-security-viz --name  sec-viz sec-viz /usr/local/bundle/bin/aws_security_viz --renderer navigator --serve 3000``` . 

You can open it with your local browser at `http://localhost:3000/navigator.html#aws-security-viz.png`. 

3.b With AWS credentials passed as parameters:

```docker run -i --rm -t -p 3000:3000 -v (pwd)/aws-viz:/aws-security-viz --name  sec-viz sec-viz /usr/local/bundle/bin/aws_security_viz -a REPLACE_AWS_ACCESS_KEY_ID -s REPLACE_SECRET --renderer navigator --serve 3000```. 

You can open it with your local browser at `http://localhost:3000/navigator.html#aws-security-viz.png`. 

Parameters passed to the docker command:
* `-v $(pwd)/aws-viz:aws-security-viz` local directory where output will be generated.
* `-i` interactive shell
* `--rm` remove the container after usage
* `-t` attach this terminal to it
* `-p 3000:3000` we expose port 3000 for the HTTP server
* `-name sec-viz` the container will have the same name as the image we will start

You can also use other parameters as specified in [usage](#USAGE)

### Help

```
$ aws_security_viz --help
Options:
  -a, --access-key=<s>       AWS access key
  -s, --secret-key=<s>       AWS secret key
  -e, --session-token=<s>    AWS session token
  -r, --region=<s>           AWS region to query (default: us-east-1)
  -v, --vpc-id=<s>           AWS VPC id to show
  -o, --source-file=<s>      JSON source file containing security groups
  -f, --filename=<s>         Output file name (default: aws-security-viz.png)
  -c, --config=<s>           Config file (opts.yml) (default: opts.yml)
  -l, --color                Colored node edges
  -u, --source-filter=<s>    Source filter
  -t, --target-filter=<s>    Target filter
  --serve=<i>                Serve a HTTP server at specified port
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

`$ aws-vault exec <profile> -- aws_security_viz -f aws.json --renderer navigator`

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

![](https://github.com/anaynayak/aws-security-viz/raw/master/images/sample.png)

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
