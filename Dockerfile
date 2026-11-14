# syntax=docker/dockerfile:1
FROM ruby:4.0-alpine@sha256:8ad6909db16ad53b5dc90bb8cc157e5fdd89ba1172798316b95cfd2a61f14b1e AS build
# apk packages track the pinned base image's Alpine release; Alpine keeps only current versions in its index, so exact pins would break builds.
RUN apk add --no-cache build-base
WORKDIR /app
ENV BUNDLE_DEPLOYMENT=true \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_PATH=/app/vendor/bundle
COPY Gemfile Gemfile.lock aws_security_viz.gemspec LICENSE.md README.md CHANGELOG.md ./
COPY lib ./lib
COPY exe ./exe
# Installs the dependency versions pinned in Gemfile.lock; the gem itself is used from this source tree.
RUN bundle install

FROM ruby:4.0-alpine@sha256:8ad6909db16ad53b5dc90bb8cc157e5fdd89ba1172798316b95cfd2a61f14b1e
# Same as above: unpinned apk packages, tied to the pinned Alpine release.
RUN apk add --no-cache graphviz font-dejavu \
 && addgroup -S viz && adduser -S -G viz -h /home/viz viz \
 && mkdir /work && chown viz:viz /work
COPY --from=build /app /app
ENV BUNDLE_GEMFILE=/app/Gemfile \
    BUNDLE_DEPLOYMENT=true \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_PATH=/app/vendor/bundle
USER viz
WORKDIR /work
ENTRYPOINT ["bundle", "exec", "aws_security_viz"]
