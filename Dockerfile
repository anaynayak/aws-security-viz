FROM ruby:2.6-alpine
RUN apk add --update graphviz ttf-ubuntu-font-family
RUN gem install aws_security_viz --pre
WORKDIR /aws-security-viz
ENTRYPOINT ["/bin/sh"]
