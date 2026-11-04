# Releasing rules_elide

Releases use [release-please](https://github.com/googleapis/release-please),
GitHub Releases, and the Bazel Central Registry (BCR). See the actual
[workflow](.github/workflows/release.yml) before changing permissions or pins.

## Release sequence

1. Land Conventional Commits on `main`; release-please proposes the version and
   changelog in a release PR. Review compatibility, tests, security-sensitive
   changes, and direct commits that have not had independent human review.
2. Merging the release PR creates a **draft** release. The tag job creates an
   annotated tag at the release commit, signed when the GPG key is configured.
3. The canonical `release_ruleset` reusable workflow checks out that tag, runs
   its configured test gate, and invokes `release_prep.sh` to prepare source,
   documentation, and SPDX SBOM archives. It produces provenance attestations
   and attaches artifacts to the draft release.
4. `publish-to-bcr` prepares/attests the registry entry and pushes it to the
   registry fork. The draft release is published only after this completes.
5. A final job opens the BCR PR under the configured maintainer identity, as a
   draft for review. Publishing is an explicit external action of the workflow.

The workflow's release gate is the analysis suite. Before cutting a compiler or
runtime release, also verify the relevant full root/integration results in
[CONTRIBUTING.md](CONTRIBUTING.md); do not mistake analysis for runtime testing.

## Verify published artifacts

Replace `X.Y.Z` with the release being verified:

```sh
gh release download vX.Y.Z --repo elide-dev/rules_elide --pattern 'rules_elide-*.tar.gz'
gh attestation verify rules_elide-vX.Y.Z.tar.gz --repo elide-dev/rules_elide
```

Inspect the verified provenance and expected canonical builder identity. A
successful verification establishes the attested origin; it does not establish
that the source is vulnerability-free or independently reproducible. Verify
available SBOM/provenance assets for the particular release rather than assuming
all historical releases have identical metadata.

The two BCR reusable workflows intentionally retain tag references because the
registry verifier expects tag-ref builder identities. See the documented
[pin exceptions](docs/security-model.md#reusable-workflow-pin-exceptions).

## Maintainer prerequisites

- `PUBLISH_TOKEN`: access required by release-please, the tag push, and the
  `elide-dev/bazel-central-registry` fork. The current workflow documents its
  enterprise-policy constraint; reassess scope and prefer a narrower credential
  when the publishing flow permits it.
- `ELIDEBOT_GPG_PRIVATE_KEY`: optional tag-signing key. Missing it produces an
  unsigned annotated tag; provenance attestation is a separate mechanism.
- `PR_TOKEN_SGAMMON`: used only to open the BCR draft PR under the configured
  maintainer identity. Never echo it or include it in artifacts.
- The registry fork, `bcr` environment, verified author email/CLA, and permission
  to publish attestations must be configured. OIDC signs provenance; it does not
  require a long-lived signing token.
- Verify backups/recovery with another authorized maintainer and record evidence
  privately. Do not put secrets or recovery material in this repository.
