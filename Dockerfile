# syntax=docker/dockerfile:1
FROM ruby:4.0-alpine AS build
RUN apk add --no-cache build-base
WORKDIR /src
COPY aws_security_viz.gemspec LICENSE.md README.md CHANGELOG.md ./
COPY lib ./lib
COPY exe ./exe
RUN gem build aws_security_viz.gemspec \
 && gem install --no-document --install-dir /gems ./aws_security_viz-*.gem

FROM ruby:4.0-alpine
RUN apk add --no-cache graphviz font-dejavu \
 && addgroup -S viz && adduser -S -G viz -h /home/viz viz \
 && mkdir /work && chown viz:viz /work
COPY --from=build /gems /gems
ENV GEM_PATH=/gems:/usr/local/bundle \
    PATH=/gems/bin:$PATH
USER viz
WORKDIR /work
ENTRYPOINT ["aws_security_viz"]
