# Security policy

## 1. Supported versions

Security fixes go into the latest release only. The current series is 1.x; releases before 1.0.0 are not supported.

## 2. Reporting a vulnerability

1. Report privately through GitHub: https://github.com/anaynayak/aws-security-viz/security/advisories/new
2. Do not open a public issue, pull request or discussion for a suspected vulnerability.
3. Include:
   1. the affected version (`aws_security_viz --version`) and how it was installed (gem or container image);
   2. what you did, what you expected and what happened, ideally with a minimal input (a redacted
      `aws ec2 describe-security-groups` JSON file, the command line, the output format);
   3. the impact you see, for example credential exposure, script injection in the HTML report, or
      unredacted data in `--obfuscate` output;
   4. any suggested fix.
4. Do not include real credentials, account ids or customer data. Redact them or use made-up values.

## 3. Scope

In scope:

1. The `aws_security_viz` gem and CLI, and the container image published at `ghcr.io/anaynayak/aws-security-viz`.
2. Handling of AWS credentials, including logging and error output.
3. The generated outputs: the HTML report, JSON, Mermaid and DOT files, and the rendered images.
4. `--obfuscate`, where output reveals data it is documented to hide.
5. The release and build pipeline in `.github/workflows`.

Out of scope:

1. Vulnerabilities in the AWS SDK, Graphviz, Cytoscape.js or Ruby themselves. Report those upstream; a report here is
   welcome if this project can mitigate the issue.
2. Findings about your AWS account that the tool reports, such as an open security group. That is the tool working as
   intended.
3. Reports that depend on running the tool with credentials or input files you do not control, or on an attacker who
   already has local access to your account or machine.
4. Denial of service from deliberately huge input files.

## 4. Data handling

The statements below describe the code in `lib/aws_security_viz`.

1. AWS API calls. With live AWS access the tool makes read-only EC2 calls and nothing else:
   1. `ec2:DescribeSecurityGroups`, always, paginated;
   2. `ec2:DescribeRegions`, only with `--all-regions`;
   3. `ec2:DescribeNetworkInterfaces`, only with `--show-unused`.

   It never creates, modifies or deletes anything. With `--source-file` it reads a local JSON file and makes no AWS
   calls. Resolving credentials is done by the AWS SDK for Ruby, so depending on your setup the SDK may also contact
   the instance metadata service, STS or SSO endpoints; the tool does not control that.
2. Credentials. They come from `-a/--access-key`, `-s/--secret-key` and `-e/--session-token`, the `AWS_ACCESS_KEY_ID`,
   `AWS_SECRET_ACCESS_KEY` and `AWS_SESSION_TOKEN` environment variables (or the legacy `AWS_ACCESS_KEY` and
   `AWS_SECRET_KEY`), or a profile, and are passed straight to the SDK client. The tool does not write them to disk,
   to the output file, or to its logs, and the SDK's HTTP wire trace is not enabled. Two things remain your
   responsibility:
   1. Keys and tokens given as `-a`, `-s` or `-e` are visible in the process list and shell history. Prefer environment variables, a
      profile or SSO, or short-lived session credentials.
   2. Diagnostics go to stderr. Error messages from AWS (including region, permission and request details) are printed,
      and `--debug` adds stack traces. Review stderr before pasting it into a public issue.
3. Local files. The tool writes only the output file you name (`aws-security-viz.html` when `-f` is not given) and, with `setup`, an `opts.yml` containing no secrets.
   It reads the file given by `--source-file` and `opts.yml`.
4. Report contents. Outputs contain security group names, ids, VPC ids, regions, CIDR ranges, ports and rule
   descriptions. This describes your network exposure, so treat the files as sensitive and share them accordingly.
5. HTML report. The file is self-contained: Cytoscape.js and the graph data are inlined, and the page has a
   Content-Security-Policy of `default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:`.
   It contains no external scripts, stylesheets, fonts or links, and its code makes no network requests, so it opens
   from `file://` offline. Data is embedded as JSON with `<` escaped and displayed through `textContent`, never as markup.
6. Obfuscation. `--obfuscate` (or `OBFUSCATE=true`) replaces, in every output format and in `--debug` logs:
   1. node ids, which cover group ids and CIDR or prefix-list peers;
   2. group names, VPC ids, regions and group-id labels;
   3. port labels, hashed per port token;
   4. rule description text.

   Each value becomes the first 10 hex characters of its unsalted SHA-256. This hides values from a casual reader
   but is not anonymisation:
   1. Small value spaces such as port numbers and IPv4 addresses can be recovered by hashing candidates.
   2. The graph's shape, the number of nodes and edges, the ingress or egress direction, and the risky and unused
      flags remain visible.
   3. With `--obfuscate`, the tool's own warnings and `--debug` output hash names, ids and regions, but AWS error
      messages and option-validation messages are printed as received and may still contain raw values, such as a
      group name passed as a filter.

   Inspect an obfuscated report before sharing it outside your organisation.

## 5. Disclosure timeline

1. Acknowledgement of a report within 7 days.
2. A fix, or a written plan with a date, within 30 days.
3. Fixes are released as a new version with a note in `CHANGELOG.md` and, where warranted, a GitHub security advisory.
   Reporters are credited there unless they prefer to stay anonymous.

## 6. Verifying releases

Releases made after the build pipeline described in `RELEASING.md` was added carry build provenance and an SBOM. The
1.0.0 release predates them, so these checks apply from the next release. `RELEASING.md` has the full commands.

1. Build provenance: `gh attestation verify aws_security_viz-<version>.gem --repo anaynayak/aws-security-viz`
   after `gem fetch aws_security_viz -v <version>`.
2. SBOM: a CycloneDX SBOM for the gem is attested (`--predicate-type https://cyclonedx.org/bom`) and attached to the
   GitHub release as `aws_security_viz-<version>.sbom.cdx.json`.
3. Container image provenance:
   `gh attestation verify oci://ghcr.io/anaynayak/aws-security-viz:<version> --repo anaynayak/aws-security-viz`.
4. Reproducible gem build: `script/build-reproducible` rebuilds the gem from the tagged commit, so you can compare its
   sha256 with the published gem. Use the same Ruby and RubyGems as the release job.
5. The gem is published to RubyGems with trusted publishing (OIDC, no stored API key), and RubyGems holds its own
   Sigstore attestation for it.
