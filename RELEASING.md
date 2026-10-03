# Releasing

Releases are cut by the maintainer. Pushing a `v*` tag runs `.github/workflows/rubygem_release.yml`, which:

1. checks the tag matches `lib/aws_security_viz/version.rb`;
2. publishes the gem to RubyGems with trusted publishing (OIDC, no API key stored in GitHub);
3. builds a multi-arch image (amd64 + arm64) and pushes it to `ghcr.io/anaynayak/aws-security-viz`, tagged
   `<version>`, `<major>.<minor>` and `latest`.

Every pull request also builds the image and smoke-tests it (the `docker image` job in `ruby.yml`), so a broken
Dockerfile shows up before a release.

## One-time setup

### 1. RubyGems trusted publisher

1. Sign in to rubygems.org as an owner of `aws_security_viz` (MFA must be enabled on the account).
2. Open https://rubygems.org/gems/aws_security_viz/trusted_publishers and choose "Create".
3. Fill in the form:
   1. Trusted publisher type: `GitHub Actions`
   2. Repository owner: `anaynayak`
   3. Repository name: `aws-security-viz`
   4. Workflow filename: `rubygem_release.yml` (file name only, not the path)
   5. Environment: `release`
4. Save. The environment value must match the workflow's `environment: release` exactly, or the publish step fails
   with an OIDC "no matching trusted publisher" error.

### 2. GitHub `release` environment

1. GitHub -> repository -> Settings -> Environments -> New environment, name it `release`.
2. Under "Deployment branches and tags", choose "Selected branches and tags" and add a tag rule `v*`. Only release
   tags can then use the environment, and therefore only they can mint the RubyGems OIDC token.
3. Optional: add yourself under "Required reviewers" so every publish waits for an approval click.

### 3. Old credentials

After the first successful trusted-publisher release:

1. Delete the `RUBYGEMS_AUTH_TOKEN` repository secret (Settings -> Secrets and variables -> Actions) and revoke the
   matching API key on rubygems.org (avatar -> Settings -> API keys).
2. Delete the `DOCKER_USERNAME` and `DOCKER_PASSWORD` secrets if present; Docker Hub is no longer used.
3. Optional: add a note to the Docker Hub `anay/aws-security-viz` description pointing to the GHCR image.

### 4. GHCR package visibility

New GHCR packages are private. After the first release pushes the image:

1. GitHub -> your profile -> Packages -> `aws-security-viz` -> Package settings.
2. "Change visibility" -> Public, so `docker pull` works without logging in.
3. Check that the package shows `anaynayak/aws-security-viz` under "Repository source"; the image's
   `org.opencontainers.image.source` label links it automatically.

## Cutting a release

1. Bump `lib/aws_security_viz/version.rb`, finish the `CHANGELOG.md` entry, commit on `main`, and wait for CI.
2. Tag and push: `git tag v1.0.0 && git push origin main v1.0.0` (the tag must be `v` + the version).
3. Watch Actions -> "Ruby Gem Release". If you added required reviewers, approve the `release` deployment.
4. Verify:
   1. `gem install aws_security_viz -v 1.0.0 && aws_security_viz --version`
   2. `docker run --rm ghcr.io/anaynayak/aws-security-viz:1.0.0 --version`
