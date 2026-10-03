---
description: Generate your first security group graph from a JSON file, from a live AWS profile, or in Docker.
---

# Quickstart

The output format follows the extension of `-f/--output`. Without `-f` the tool writes `aws-security-viz.html`.

## From a JSON file

This route needs no AWS access. Download the sample [security_groups.json](assets/security_groups.json), or create one
from your own account with the AWS CLI:

```
aws ec2 describe-security-groups > security_groups.json
```

Then render it:

```
aws_security_viz -o security_groups.json -f viz.html
```

```
[WARN] 1 risky edge: public ingress (0.0.0.0/0 or ::/0) on a sensitive port or all traffic
```

Open `viz.html` in a browser. The warning goes to stderr and names the number of risky edges; the sample contains one
(`0.0.0.0/0` on port 22). Other formats are a change of extension:

```
aws_security_viz -o security_groups.json -f viz.svg
aws_security_viz -o security_groups.json -f viz.mmd
```

## From AWS

There is no built-in default region, so give one with `-r/--region` or `AWS_REGION`, or use a profile that has one.

```
aws_security_viz --profile <profile_name> --region us-west-1 -f viz.html
```

For SSO profiles run `aws sso login --profile <profile_name>` first. With
[aws-vault](https://github.com/99designs/aws-vault/) and short-lived credentials:

```
aws-vault exec <profile_name> -- aws_security_viz --region us-west-1 -f viz.html
```

See [Credentials and IAM](credentials-and-iam.md) for the full credential order and the IAM policy.

## In Docker

Create an output directory first (`mkdir aws-viz`), then mount it at `/work`.

=== "aws-vault"

    ```
    aws-vault exec <profile_name> -- docker run --rm --user $(id -u):$(id -g) \
      -e AWS_REGION=us-west-1 -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_SESSION_TOKEN -e AWS_SECURITY_TOKEN \
      -v "$(pwd)/aws-viz:/work" ghcr.io/anaynayak/aws-security-viz:<version> -f /work/aws.svg
    ```

    aws-vault does not set a region. Pass one with `-e AWS_REGION=<region>`, or `-e AWS_REGION` after exporting it on the
    host.

=== "SSO profile"

    Run `aws sso login --profile <profile_name>` first.

    ```
    docker run --rm --user $(id -u):$(id -g) -e HOME=/home/viz -e AWS_PROFILE=<profile_name> -e AWS_REGION=us-west-1 \
      -v "$HOME/.aws:/home/viz/.aws" -v "$(pwd)/aws-viz:/work" \
      ghcr.io/anaynayak/aws-security-viz:<version> -f /work/aws.svg
    ```

=== "JSON file"

    ```
    cp security_groups.json aws-viz/
    docker run --rm --user $(id -u):$(id -g) -v "$(pwd)/aws-viz:/work" \
      ghcr.io/anaynayak/aws-security-viz:<version> -o /work/security_groups.json -f /work/viz.html
    ```

!!! note "Linux bind mounts"
    `--user $(id -u):$(id -g)` matters on Linux. Bind mounts keep the host's ownership, so the container's non-root user
    cannot write to a directory owned by you and the run fails with "Permission denied". Running as your own uid and gid
    fixes that and leaves the output files owned by you. Docker Desktop on macOS does not need it.

`--rm` removes the container after the run. Any option from [Configuration](configuration.md) can follow the image name.

## Next steps

1. Look at the [viewer tour](outputs.md#html-viewer).
2. Narrow the graph with [filters](filtering-and-risk-checks.md#source-and-target-filters).
3. Gate a CI job with [`--fail-on-risk`](filtering-and-risk-checks.md#failing-a-ci-job).
