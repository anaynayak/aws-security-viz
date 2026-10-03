---
description: Install aws-security-viz from RubyGems or run the published container image, and check the requirements.
---

# Installation

## Requirements

1. Ruby 3.3 or newer. CI tests Ruby 3.3, 3.4 and 4.0.
2. Graphviz (`brew install graphviz` on macOS), only for image formats such as png, svg and pdf. The HTML, JSON, Mermaid
   and DOT outputs do not need it.

## Gem or container image

=== "Gem"

    ```
    gem install aws_security_viz
    aws_security_viz --version
    ```

=== "Docker"

    ```
    docker pull ghcr.io/anaynayak/aws-security-viz:<version>
    docker run --rm ghcr.io/anaynayak/aws-security-viz:<version> --version
    ```

The image is multi-arch (amd64 and arm64) and is published to `ghcr.io/anaynayak/aws-security-viz` by the release
workflow. Tags:

| Tag | Meaning |
| --- | --- |
| `<version>` | An exact release, for example `1.0.0`. Pin this for reproducible runs. |
| `<major>.<minor>` | The latest patch of a series, for example `1.0`. |
| `latest` | The latest stable release. |

The image's entrypoint is `bundle exec aws_security_viz`, so everything after the image name is a normal CLI argument.
It runs as a non-root user with `/work` as the working directory; mount a local directory there to get the output
files. See [Quickstart](quickstart.md#in-docker) for run recipes.

## Build from a checkout

```
git clone https://github.com/anaynayak/aws-security-viz
cd aws-security-viz
bundle install
bundle exec exe/aws_security_viz --version
```

To build the image from the checkout: `docker build -t sec-viz .` and use `sec-viz` in place of the `ghcr.io` name.

## Verify a release

Releases carry build provenance and an SBOM from the next release onward. See
[Security](security.md#6-verifying-releases) for the commands.
