FROM ruby:2.6-alpine
RUN apk add --update \
        build-base \
        graphviz \
        ttf-ubuntu-font-family
RUN gem install aws_security_viz --pre
RUN apk del build-base
WORKDIR /aws-security-viz
CMD ["aws_security_viz"]
