---
description: How aws-security-viz finds AWS credentials and a region, the minimal IAM policy, and which flag needs which EC2 action.
---

# Credentials and IAM

## Credential sources

Credentials and the region come from the AWS SDK for Ruby chain. The tool adds these inputs on top:

| Source | Notes |
| --- | --- |
| `-p/--profile=NAME` | A shared-config profile, including SSO profiles after `aws sso login --profile <profile_name>`. A profile beats explicit keys. |
| `-a`, `-s`, `-e` | Access key, secret key and session token. Also read from `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_SESSION_TOKEN` (and the legacy `AWS_ACCESS_KEY` and `AWS_SECRET_KEY`). |
| SDK default chain | `AWS_PROFILE`, environment variables, SSO, shared config, container and instance roles. |
| aws-vault | `aws-vault exec <profile_name> -- aws_security_viz ...` exports short-lived credentials as environment variables. |

!!! warning
    Keys passed with `-a`, `-s` or `-e` are visible in the process list and shell history. Prefer a profile, aws-vault,
    SSO or environment variables.

There is no built-in default region. Without one the tool stops with:

```
[ERROR] no AWS region; pass -r/--region or set AWS_REGION (or use a profile with a region)
```

Without credentials it stops with `no AWS credentials found; pass -a/-s, set AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY, or
use --profile`. With `--source-file` the tool reads a local JSON file and makes no AWS calls.

## Minimal IAM policy

The tool is read-only. It always calls `ec2:DescribeSecurityGroups`; two flags call more:

| Flag | EC2 action | If missing |
| --- | --- | --- |
| (always) | `ec2:DescribeSecurityGroups` | The run fails. |
| `--all-regions` | `ec2:DescribeRegions` | The run fails. |
| `--show-unused` | `ec2:DescribeNetworkInterfaces` | The run continues with a warning and no group is marked unused. |

Add an action to the policy only if you use its flag. This policy covers every flag:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeRegions",
                "ec2:DescribeNetworkInterfaces"
            ],
            "Resource": "*"
        }
    ]
}
```

The tool never creates, modifies or deletes anything. Resolving credentials is done by the SDK, so depending on your
setup the SDK may also contact the instance metadata service, STS or SSO endpoints.

## Several regions

With `--all-regions`, `-r` (the first name if a list) is only the region used to call `DescribeRegions`. A region that
fails with `UnauthorizedOperation`, `AuthFailure` or `OptInRequired` is skipped with a warning. The run fails only if
every region fails.
