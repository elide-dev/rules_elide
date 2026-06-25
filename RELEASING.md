# Releasing rules_elide

Releases are automated with [release-please](https://github.com/googleapis/release-please)
and published to GitHub Releases and the [Bazel Central Registry](https://registry.bazel.build/).

## Cutting a release

1. Land changes on `main` using [Conventional Commits](https://www.conventionalcommits.org)
   (`feat:`, `fix:`, `chore:`, `feat!:`/`BREAKING CHANGE:` for majors). The
   commitizen pre-commit hook enforces the format.
2. release-please maintains a **release PR** that bumps the version
   (`.release-please-manifest.json`) and updates `CHANGELOG.md`.
3. Merge the release PR. The `release.yml` workflow then:
   - creates the `vX.Y.Z` tag and GitHub Release;
   - builds `rules_elide-vX.Y.Z.tar.gz` (source) and `…docs.tar.gz` (Stardoc);
   - generates an SPDX SBOM (`…spdx.json`), enriched with the `MODULE.bazel`
     dependency closure;
   - attaches all three assets and attests **build provenance** (SLSA Build L2)
     and the **SBOM**, signed keyless via Sigstore (Fulcio + Rekor);
   - opens a Bazel Central Registry PR via `bazel-contrib/publish-to-bcr`.

## Verifying provenance

```sh
gh attestation verify rules_elide-vX.Y.Z.tar.gz --repo elide-dev/rules_elide
```

This checks the Sigstore-signed provenance: that the artifact was built by this
repo's `release.yml` on GitHub-hosted runners.

## Prerequisites (one-time, maintainers)

- `PUBLISH_TOKEN` repo secret: push access to the `elide-dev/bazel-central-registry`
  fork (consumed by the `bcr` job).
- The `elide-dev/bazel-central-registry` fork must exist.
- No token is needed for attestations — they use GitHub OIDC.
