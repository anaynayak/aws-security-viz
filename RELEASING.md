# Releasing

Releases are cut by the maintainer. Pushing a `v*` tag triggers
`.github/workflows/rubygem_release.yml`, which publishes the gem to RubyGems using trusted publishing (OIDC). There
is no API key stored in GitHub.

## One-time setup (manual)

1. On rubygems.org, open the `aws_security_viz` gem -> Settings -> Trusted publishers -> GitHub Actions, and add:
   1. Owner: `anaynayak`
   2. Repository: `aws-security-viz`
   3. Workflow filename: `rubygem_release.yml`
   4. Environment: `release`
2. On GitHub, create an environment named `release` (repo Settings -> Environments). Optionally add required
   reviewers so each publish needs an approval click.
3. Once a trusted-publisher release has succeeded, delete the old `RUBYGEMS_AUTH_TOKEN` repository secret and revoke
   the matching API key on rubygems.org.

## Cutting a release

1. Bump `lib/version.rb` and finish the `CHANGELOG.md` entry; commit on `main` and make sure CI is green.
2. Tag and push: `git tag v0.3.0 && git push origin main v0.3.0` (the tag must equal `v` + the version).
3. Watch the "Ruby Gem Release" workflow. It fails early if the tag and `lib/version.rb` disagree.
