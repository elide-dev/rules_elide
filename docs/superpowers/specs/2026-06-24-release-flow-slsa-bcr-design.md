# Release flow: BCR + SLSA + Sigstore + SBOM — design

**Date:** 2026-06-24
**Status:** approved (brainstorm), pending spec review

## Goal

Harden `rules_elide`'s release flow to a security best-practice bar:

- Releases cut automatically from Conventional Commits and published to **GitHub
  Releases** from GitHub Actions.
- Published to the **Bazel Central Registry (BCR)**.
- **Build provenance** on both the GitHub release artifacts and the BCR entry.
- **Sigstore**-backed signing (keyless, via GitHub OIDC).
- **SBOMs** (SPDX) attached to the release and attested.
- **SLSA Build Level 2** — the highest level that is worth the complexity for a
  `git archive` source tarball on GitHub-hosted runners (L3 via
  `slsa-github-generator` is documented as a future option, not built now).

This is **hardening an existing flow**, not greenfield. The repo already has the
bazel-contrib release scaffolding (it has simply never run — 0 tags/releases):
`release.yml` (uses `bazel-contrib/.github` `release_ruleset.yaml`),
`publish-to-bcr.yml` (`bazel-contrib/publish-to-bcr`), `.bcr/` templates, and
`release_prep.sh`. The `e2e/smoke` module is the BCR test module.

## Decisions (locked during brainstorm)

| Decision | Choice | Rationale |
| --- | --- | --- |
| SLSA mechanism | GitHub native attestations (`actions/attest-build-provenance`) | SLSA Build L2, Sigstore-keyless, lowest maintenance, matches BCR's provenance model |
| SBOM | SPDX 2.3 JSON (syft over tarball + `MODULE.bazel` dep closure) | GitHub-native (`actions/attest-sbom` supports SPDX), most widely consumed |
| Release trigger | `release-please` (Conventional Commits → release PR → tag → release) | Automated versioning + changelog; Conventional Commits already enforced (commitizen pre-commit hook) |

## Architecture: one orchestrated `release.yml`

`release-please` and the bazel-contrib `release_ruleset.yaml` both want to *own*
release creation, and **releases created with the default `GITHUB_TOKEN` do not
trigger downstream `on: release` workflows** (GitHub's recursion guard). So the
flow is consolidated into a **single orchestrated workflow** with sequential,
gated jobs instead of relying on release-event fan-out:

```
release.yml  (on: push to main; permissions: contents/id-token/attestations: write)
 ├─ job: release-please
 │     uses googleapis/release-please-action
 │     maintains the release PR; on merge cuts tag vX.Y.Z + GH Release (notes = CHANGELOG)
 │     outputs: release_created (bool), tag_name
 │
 ├─ job: assets            (needs: release-please; if: release_created)
 │     - checkout @ tag_name
 │     - run release_prep.sh  -> rules_elide-vX.Y.Z.tar.gz + .docs.tar.gz + integrity + notes
 │     - generate SPDX SBOM (syft over the source tarball) + enrich with MODULE.bazel deps
 │     - gh release upload  (tarballs + SBOM)
 │     - actions/attest-build-provenance  (subjects = tarballs + SBOM)
 │     - actions/attest-sbom              (bind SBOM to the source tarball)
 │
 └─ job: bcr               (needs: [release-please, assets]; if: release_created)
       uses bazel-contrib/publish-to-bcr publish.yaml
       with: tag_name, registry_fork: elide-dev/bazel-central-registry
       secrets: publish_token = PUBLISH_TOKEN
```

`publish-to-bcr` is invoked **as a reusable-workflow job** (not via an
`on: release` trigger), which sidesteps the `GITHUB_TOKEN` event gotcha entirely.

**Retired:** the standalone `.github/workflows/publish-to-bcr.yml` (folded into
the `bcr` job) and the existing `release.yml` body (replaced by the orchestrated
version; `release_ruleset.yaml` is no longer used because `release-please` now
owns release creation and the attestation/SBOM steps are explicit).

**Reused unchanged:** `release_prep.sh` (source + docs tarballs, integrity,
Bzlmod usage notes), `.bcr/{source,metadata,presubmit}.*`, and the `e2e/smoke`
BCR test module.

## Component detail

### release-please
- `release-please-config.json` + `.release-please-manifest.json`.
- `release-type: "simple"`, version tracked in the manifest. **No `version`
  field is added to `MODULE.bazel`** — BCR derives the version from the release
  tag, and the root module omits its own version by convention.
- Generates and maintains `CHANGELOG.md`. The manifest is seeded to `0.0.0`
  (the last-released baseline) with `bump-minor-pre-major: true` and
  `bump-patch-for-minor-pre-major: false`, so the first `feat`-driven release is
  `0.1.0`.
- Conventional Commits are already enforced by the commitizen pre-commit hook,
  so no new contributor-facing convention is introduced.
- Runs with the default `GITHUB_TOKEN` (sufficient: it opens the release PR and,
  on merge, creates the tag + release; downstream steps run in the same workflow
  so no release-event propagation is needed).

### GitHub provenance & Sigstore
- `actions/attest-build-provenance` over the source tarball, docs tarball, and
  the SBOM file → SLSA Build L2 provenance, signed **keyless via Sigstore**
  (Fulcio certificate from the GHA OIDC token, transparency-logged in Rekor).
  Verifiable downstream with `gh attestation verify <artifact> --repo elide-dev/rules_elide`.
- `actions/attest-sbom` binds the SPDX SBOM to the source tarball as a separate
  signed attestation.
- Required permissions (already present on the current workflow): `id-token:
  write`, `attestations: write`, `contents: write`.

### SBOM
- `anchore/sbom-action` (syft) produces **SPDX 2.3 JSON** over the release
  source tarball (`rules_elide-vX.Y.Z.spdx.json`).
- An enrichment step parses the **direct `bazel_dep` entries** from
  `MODULE.bazel` (name + version) and merges them into the SPDX document as
  packages with `DEPENDS_ON` relationships from the root package, so the SBOM
  reflects the Bazel dependency closure rather than only file contents. Scope is
  bounded to **direct** deps for this first cut (transitive closure is a future
  enhancement). Implemented as a dedicated helper script, `tools/sbom_prep.sh`
  (kept separate from `release_prep.sh` so asset and SBOM generation stay
  independently testable).
- The SBOM is uploaded to the GitHub release and attested (above).

### BCR provenance
- `bazel-contrib/publish-to-bcr@v1.4.1` (already pinned) supports attestations;
  the `bcr` job passes `tag_name`, `registry_fork: elide-dev/bazel-central-registry`,
  and `secrets.publish_token`. The resulting BCR PR carries provenance that ties
  the registry entry back to the signed release artifacts.
- `.bcr/source.template.json` already points at
  `releases/download/v{VERSION}/rules_elide-v{VERSION}.tar.gz` — matching the
  asset name `release_prep.sh` emits, so no `.bcr` change is needed.

## Files

**Add**
- `release-please-config.json`
- `.release-please-manifest.json` (`{ ".": "0.0.0" }`)
- `CHANGELOG.md` (seed)
- `tools/sbom_prep.sh` (SPDX generation + `MODULE.bazel` dep enrichment)

**Rewrite**
- `.github/workflows/release.yml` → the orchestrated `release-please` → `assets`
  → `bcr` workflow above

**Remove**
- `.github/workflows/publish-to-bcr.yml` (folded into the `bcr` job)

**Keep unchanged**
- `.github/workflows/release_prep.sh`, `.bcr/*`, `e2e/smoke/*`

## Secrets / configuration prerequisites (manual, outside this change)
- `PUBLISH_TOKEN` — already referenced by the current `publish-to-bcr.yml`; a
  token with push access to the `elide-dev/bazel-central-registry` fork. Must
  remain configured.
- The `elide-dev/bazel-central-registry` fork must exist (it is already the
  configured `registry_fork`).
- No upload token is needed for attestations (OIDC).

## Validation

No release exists yet, so the **first `v0.1.0` release is the real integration
test**. Before that:
- `actionlint` over the rewritten workflow (pre-commit already runs it).
- Run `release_prep.sh v0.1.0` locally to confirm asset generation and notes.
- Run the SBOM helper locally and validate the SPDX JSON (e.g. with `syft` /
  an SPDX validator) including the merged `bazel_dep` packages.
- Dry-run provenance on a throwaway pre-release tag and verify with
  `gh attestation verify`.
- The existing `.bcr` presubmit + `e2e/smoke` test module continue to gate BCR
  consumability.

## Out of scope / future
- **SLSA Build L3** via `slsa-framework/slsa-github-generator` (isolated,
  non-falsifiable provenance). Feasible but adds a separate builder workflow;
  deferred per the L2 decision.
- **Transitive** dependency closure in the SBOM (first cut covers direct
  `bazel_dep`s).
- CycloneDX output (SPDX only for now).
- Signing of the Elide toolchain binaries themselves (this flow covers the
  ruleset release artifacts; the Elide CLI is released by the upstream
  `elide-dev/elide` repo).
