---
description: Error messages from aws-security-viz with their cause and fix, and how to produce a bug report that is safe to share.
---

# Troubleshooting

## Error messages

All errors are printed to stderr as `[ERROR] ...` and the exit status is 1. Add `--debug` for a stack trace.

| Message | Cause and fix |
| --- | --- |
| `no AWS region; pass -r/--region or set AWS_REGION (or use a profile with a region)` | There is no default region. Pass `-r`, export `AWS_REGION`, or use a profile with a region. In Docker, pass `-e AWS_REGION=<region>`. |
| `no AWS credentials found; pass -a/-s, set AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY, or use --profile` | The SDK found no credentials. For SSO run `aws sso login --profile <profile_name>`. |
| `AWS <ErrorName>: ...` | An AWS service error, for example `UnauthorizedOperation`. Check the [IAM policy](credentials-and-iam.md#minimal-iam-policy). |
| `could not reach AWS: ...` | A networking error: proxy, DNS or no connectivity. |
| `cannot pick an output format from "x.txt": unknown file extension '.txt' (supported: ...)` | Use one of the [supported extensions](outputs.md). |
| `Graphviz 'dot' not found; install graphviz` | Image formats need Graphviz. Install it, or use `.html`, `.json`, `.mmd` or `.dot`. |
| `unknown layout engine 'x' (choose from: dot, neato, sfdp, fdp, twopi, circo)` | Fix `-y/--layout` or `:format:` in `opts.yml`. |
| `no group or peer matches 'x'` | The source or target filter is neither a group id nor a group name in the graph. |
| `'x' matches several groups (...); use a group id` | Two groups share the name. Filter by id. |
| `risky_ports: invalid entry 'x' (expected a port number 1-65535)` | Fix `:risky_ports:` in `opts.yml`. |
| `No such file or directory @ rb_sysopen - file.json` | The `--source-file` path is wrong. |

An empty graph usually means a filter, `:exclude:` pattern or `--vpc-id` removed everything, or the region has no
security groups.

## Produce the JSON input

```
aws ec2 describe-security-groups > security_groups.json
```

This needs the [AWS CLI](https://github.com/aws/aws-cli). Pass the file with `-o`. Add `--region` or `--profile` to
the `aws` command for the account you want.

## Report a bug

1. Re-run with `--debug`. Debug output goes to stderr.
2. Obfuscate the input and output with `--obfuscate` (or `OBFUSCATE=true`), which hashes ids, names, VPC ids, regions,
   ports and rule descriptions:

    ```
    aws_security_viz --debug --obfuscate -o security_groups.json -f viz.json
    ```

3. Open an issue on [GitHub](https://github.com/anaynayak/aws-security-viz/issues).

AWS error messages and option-validation messages are printed as received and can contain raw values, such as a group
name passed as a filter. Review stderr before pasting it. Report vulnerabilities privately; see [Security](security.md).
