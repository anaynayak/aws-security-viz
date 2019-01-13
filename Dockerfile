FROM ubuntu:latest
RUN apt-get update
# RUN gem install aws_security_viz # use bundler instead because nokogiri makes problems
RUN apt-get install -y git ruby-dev ruby graphviz libxml2-dev g++ zlib1g-dev python
RUN git clone https://github.com/anaynayak/aws-security-viz.git
WORKDIR /aws-security-viz
RUN gem install bundler --no-document
RUN bundle install
ENTRYPOINT ["/bin/sh"]
