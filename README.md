aws-security-viz -- A tool to visualize aws security groups 
============================================================
[![Build Status](https://secure.travis-ci.org/anaynayak/aws-security-viz.png)](http://travis-ci.org/anaynayak/aws-security-viz) 
[![Gem Version](https://badge.fury.io/rb/aws_security_viz.svg)](https://badge.fury.io/rb/aws_security_viz)
[![Code Climate](https://codeclimate.com/github/anaynayak/aws-security-viz.png)](https://codeclimate.com/github/anaynayak/aws-security-viz) 
[![Dependency Status](https://gemnasium.com/anaynayak/aws-security-viz.png)](https://gemnasium.com/anaynayak/aws-security-viz)

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

* graphviz with triangulation `brew install graphviz --with-gts`
* libxml2 `brew install libxml2`* 

## USAGE

To generate the graph directly using AWS keys

```
  $ aws_security_viz -a your_aws_key -s your_aws_secret_key -f viz.svg --color=true
```

To generate the graph using an existing security_groups.json (created using aws-cli)

```
  $ aws_security_viz -o data/security_groups.json -f viz.svg --color
```

``` 
$ aws_security_viz --help
Options:
  -a, --access-key=<s>     AWS access key
  -s, --secret-key=<s>     AWS secret key
  -r, --region=<s>         AWS region to query (default: us-east-1)
  -o, --source-file=<s>    JSON source file containing security groups
  -f, --filename=<s>       Output file name (default: aws-security-viz.png)
  -c, --config=<s>         Config file (opts.yml) (default: opts.yml)
  -l, --color              Colored node edges
  -h, --help               Show this message
```

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

## EXAMPLE

![](https://github.com/anaynayak/aws-security-viz/raw/master/images/sample.png)

