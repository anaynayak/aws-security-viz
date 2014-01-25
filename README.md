aws-security-viz -- A tool to visualize aws security groups 
============================================================

[![Build Status](https://secure.travis-ci.org/anaynayak/aws-security-viz.png)](http://travis-ci.org/anaynayak/aws-security-viz) [![Code Climate](https://codeclimate.com/github/anaynayak/aws-security-viz.png)](https://codeclimate.com/github/anaynayak/aws-security-viz) [![Dependency Status](https://gemnasium.com/anaynayak/aws-security-viz.png)](https://gemnasium.com/anaynayak/aws-security-viz)

## DESCRIPTION
  Need a quick way to visualize your current aws/amazon ec2 security group configuration? aws-security-viz does just that based on the EC2 security group ingress configuration. 

## FEATURES

* Output to any of the formats that Graphviz supports. 
* EC2 classic and VPC security groups

## INSTALLATION 

  $ bundle install ([more info](http://gembundler.com/bundle_install.html))

## USAGE

```
  $ ruby lib/visualize_aws.rb -a your_aws_key -s your_aws_secret_key -f viz.svg
```

## EXAMPLE

![](https://github.com/anaynayak/aws-security-viz/raw/master/images/sample.png)

