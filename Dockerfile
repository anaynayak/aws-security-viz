FROM ruby:3.4-alpine
RUN apk add --update \
        build-base \
        graphviz \
        ttf-freefont
RUN gem install aws_security_viz --pre
RUN apk del build-base
WORKDIR /aws-security-viz
CMD ["aws_security_viz"]
