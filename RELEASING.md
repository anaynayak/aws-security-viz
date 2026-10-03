# Releasing

Releases are cut by the maintainer. Pushing a `v*` tag runs `.github/workflows/rubygem_release.yml`, which:

1. checks the tag matches `lib/aws_security_viz/version.rb`, then runs `script/build-reproducible`, which
   normalises file permissions and sets `SOURCE_DATE_EPOCH` to the tagged commit's time so the gem build is
   reproducible;
2. publishes the gem to RubyGems with trusted publishing (OIDC, no API key stored in GitHub);
3. builds a multi-arch image (amd64 + arm64) and pushes it to `ghcr.io/anaynayak/aws-security-viz`, tagged
   `<version>`, `<major>.<minor>` and `latest`;
4. attests build provenance for the `.gem` and the image, and a CycloneDX SBOM for the gem (see "Verifying a
   release" below);
5. creates the GitHub release for the tag, using the matching `CHANGELOG.md` section as the notes, with the
   provenance bundle (`aws_security_viz-<version>.intoto.jsonl`) and the SBOM
   (`aws_security_viz-<version>.sbom.cdx.json`) attached.

Every pull request also builds the image and smoke-tests it (the `docker image` job in `ruby.yml`), so a broken
Dockerfile shows up before a release.

The `reproducible gem build` job in `ruby.yml` builds the gem twice from the same commit with
`script/build-reproducible`, in different directories, with different umasks (022 and 002) and time zones, and
fails if the two sha256 checksums differ.

To check a published gem yourself (applies from the first release made after this script was added; 1.0.0 predates
it and is not reproducible this way):

1. Use the same Ruby and RubyGems as the release job: Ruby 3.4 from `ruby/setup-ruby` on `ubuntu-latest`. The gem
   metadata records `rubygems_version`, so a different RubyGems gives a different checksum. Check the release
   job's log for the exact versions.
2. Make a clean checkout of the release tag (`git clone --branch v<version> https://github.com/anaynayak/aws-security-viz`).
3. Run `script/build-reproducible /tmp/rebuilt.gem` from the checkout root.
4. Compare `sha256sum /tmp/rebuilt.gem` with the gem from `gem fetch aws_security_viz -v <version>`.

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
2. Tag and push: `git tag v<version> && git push origin main v<version>` (the tag must be `v` + the version).
3. Watch Actions -> "Ruby Gem Release". If you added required reviewers, approve the `release` deployment.
4. Verify:
   1. `gem install aws_security_viz -v <version> && aws_security_viz --version`
   2. `docker run --rm ghcr.io/anaynayak/aws-security-viz:<version> --version`

## Verifying a release

Attestations, the SBOM and reproducible builds exist from the release after 1.0.0; 1.0.0 predates them.
RubyGems.org also stores its own Sigstore attestation for the gem (published by `rubygems/release-gem`). The GitHub
attestations below are separate and are checked with the `gh` CLI.

1. Gem build provenance:
   ```
   gem fetch aws_security_viz -v <version>
   gh attestation verify aws_security_viz-<version>.gem --repo anaynayak/aws-security-viz
   ```
2. Gem SBOM attestation:
   ```
   gh attestation verify aws_security_viz-<version>.gem --repo anaynayak/aws-security-viz \
     --predicate-type https://cyclonedx.org/bom
   ```
3. Image provenance (stored in the registry next to the image):
   ```
   gh attestation verify oci://ghcr.io/anaynayak/aws-security-viz:<version> --repo anaynayak/aws-security-viz
   ```
4. Offline, using the bundle attached to the GitHub release:
   ```
   gh attestation verify aws_security_viz-<version>.gem --repo anaynayak/aws-security-viz \
     --bundle aws_security_viz-<version>.intoto.jsonl
   ```
