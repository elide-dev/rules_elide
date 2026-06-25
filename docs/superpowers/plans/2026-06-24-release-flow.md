# Release Flow (BCR + SLSA L2 + Sigstore + SBOM) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the scaffolded-but-unused release setup into a working, automated release flow: release-please versioning → GitHub Release with SBOM + Sigstore build-provenance (SLSA Build L2) → Bazel Central Registry publish with provenance.

**Architecture:** One orchestrated `.github/workflows/release.yml` with three sequential, gated jobs — `release-please` (cuts tag + release), `assets` (builds tarballs, generates+enriches an SPDX SBOM, uploads, attests provenance + SBOM via Sigstore-keyless GitHub attestations), and `bcr` (calls `bazel-contrib/publish-to-bcr` as a reusable workflow). The standalone `publish-to-bcr.yml` is folded in; `release_prep.sh`, `.bcr/*`, and `e2e/smoke` are reused unchanged.

**Tech Stack:** GitHub Actions, `googleapis/release-please-action` v5, `actions/attest-build-provenance` + `actions/attest-sbom` v4 (Sigstore/Fulcio/Rekor), `anchore/sbom-action` (syft → SPDX 2.3), `bazel-contrib/publish-to-bcr` v1.4.1, Python 3 (SBOM enrichment), Bash.

## Global Constraints

- **Pin every GitHub Action by full commit SHA** with a trailing `# vX.Y.Z` comment (repo convention; gitleaks/actionlint enforced via pre-commit).
- **Conventional Commits** are required for commit messages (already enforced by the commitizen pre-commit hook); release-please depends on them.
- **No `version` field in `MODULE.bazel`** — BCR derives the version from the release tag; release-please tracks it in `.release-please-manifest.json`.
- Release tag format is **`vX.Y.Z`** (matches `.bcr/source.template.json` and `release_prep.sh`).
- CI/release runners: **`ubuntu-24.04`**. Every job starts with the `step-security/harden-runner` step (`egress-policy: audit`).
- Commit messages end with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. **Never** add a Claude Code advertising footer.

### Pinned action SHAs (resolved 2026-06-24)

| Action | Version | SHA |
| --- | --- | --- |
| `googleapis/release-please-action` | v5.0.0 | `45996ed1f6d02564a971a2fa1b5860e934307cf7` |
| `actions/attest-build-provenance` | v4.1.0 | `a2bbfa25375fe432b6a289bc6b6cd05ecd0c4c32` |
| `actions/attest-sbom` | v4.1.0 | `c604332985a26aa8cf1bdc465b92731239ec6b9e` |
| `anchore/sbom-action` | v0.24.0 | `e22c389904149dbc22b58101806040fa8d37a610` |
| `actions/checkout` | v7.0.0 | `9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0` |
| `step-security/harden-runner` | v2.19.4 | `9af89fc71515a100421586dfdb3dc9c984fbf411` |
| `bazel-contrib/publish-to-bcr/.github/workflows/publish.yaml` | v1.4.1 | `c316f1611511a40423572303f66c80bb30bfe2f8` |

---

### Task 1: release-please configuration

**Files:**
- Create: `release-please-config.json`
- Create: `.release-please-manifest.json`
- Create: `CHANGELOG.md`

**Interfaces:**
- Produces: a release-please setup that, on merge of its release PR, creates git tag `vX.Y.Z` and a GitHub Release. Consumed by Task 3's workflow via `config-file` / `manifest-file` inputs and the `release_created` / `tag_name` step outputs.

- [ ] **Step 1: Create `release-please-config.json`**

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "packages": {
    ".": {
      "release-type": "simple",
      "package-name": "rules_elide",
      "changelog-path": "CHANGELOG.md",
      "include-component-in-tag": false,
      "bump-minor-pre-major": true,
      "bump-patch-for-minor-pre-major": false,
      "draft": false,
      "prerelease": false
    }
  }
}
```

Notes: `include-component-in-tag: false` ⇒ tags are `vX.Y.Z` (not `rules_elide-vX.Y.Z`). `release-type: "simple"` tracks the version in the manifest (no in-repo version file is updated, which is correct for a Bazel module). With `bump-minor-pre-major: true` and `bump-patch-for-minor-pre-major: false`, pre-1.0 `feat` commits bump the minor version (breaking changes are capped at minor), so from the `0.0.0` baseline the first release is `0.1.0`.

- [ ] **Step 2: Create `.release-please-manifest.json`** (seed the last-released baseline; release-please bumps from here)

```json
{
  ".": "0.0.0"
}
```

- [ ] **Step 3: Create `CHANGELOG.md`** (seed; release-please appends here)

```markdown
# Changelog
```

- [ ] **Step 4: Validate the JSON parses**

Run: `python3 -c "import json; json.load(open('release-please-config.json')); json.load(open('.release-please-manifest.json')); print('ok')"`
Expected: `ok`

- [ ] **Step 5: Commit**

```bash
git add release-please-config.json .release-please-manifest.json CHANGELOG.md
git commit -m "chore(release): add release-please config (seed 0.0.0)"
```

---

### Task 2: SPDX SBOM enrichment tool

**Files:**
- Create: `tools/sbom_enrich.py`
- Create: `tools/sbom_enrich_test.py`
- Create: `tools/sbom_prep.sh` (local convenience wrapper)

**Interfaces:**
- Produces:
  - `parse_bazel_deps(module_text: str) -> list[tuple[str, str]]` — direct `bazel_dep` `(name, version)` pairs.
  - `enrich(spdx: dict, deps: list[tuple[str, str]]) -> dict` — mutates+returns the SPDX doc, adding one package + `DEPENDS_ON` relationship per dep.
  - CLI: `python3 tools/sbom_enrich.py <spdx.json> <MODULE.bazel>` mutates `<spdx.json>` in place.
  - `tools/sbom_prep.sh <tag>` — generates `rules_elide-<tag>.spdx.json` from the tarball via syft, then enriches it. Used locally; the CI workflow (Task 3) calls `anchore/sbom-action` + `sbom_enrich.py` directly.
- Consumed by: Task 3's `assets` job (`python3 tools/sbom_enrich.py "$SBOM" MODULE.bazel`).

- [ ] **Step 1: Write the failing tests**

Create `tools/sbom_enrich_test.py`:

```python
# SPDX-License-Identifier: Apache-2.0
"""Tests for the SPDX SBOM bazel_dep enrichment helper."""

from sbom_enrich import enrich, parse_bazel_deps

_MODULE = """
module(name = "rules_elide")
bazel_dep(name = "platforms", version = "1.1.0")
bazel_dep(name = "rules_kotlin", version = "2.4.0")
bazel_dep(name = "stardoc", version = "0.8.1", dev_dependency = True)
local_path_override(module_name = "ignored", path = "..")
"""


def test_parse_bazel_deps_extracts_name_and_version():
    deps = parse_bazel_deps(_MODULE)
    assert ("platforms", "1.1.0") in deps
    assert ("rules_kotlin", "2.4.0") in deps
    assert ("stardoc", "0.8.1") in deps  # dev_dependency entries included
    assert all(name != "ignored" for name, _ in deps)  # non-bazel_dep ignored


def test_enrich_adds_package_and_relationship():
    spdx = {
        "documentDescribes": ["SPDXRef-Package-root"],
        "packages": [{"SPDXID": "SPDXRef-Package-root", "name": "rules_elide"}],
    }
    enrich(spdx, [("platforms", "1.1.0")])
    pkg = next(p for p in spdx["packages"] if p.get("name") == "platforms")
    assert pkg["versionInfo"] == "1.1.0"
    assert pkg["externalRefs"][0]["referenceLocator"] == "pkg:bazel/platforms@1.1.0"
    rel = spdx["relationships"][0]
    assert rel["relationshipType"] == "DEPENDS_ON"
    assert rel["spdxElementId"] == "SPDXRef-Package-root"
    assert rel["relatedSpdxElement"] == pkg["SPDXID"]


def test_enrich_is_idempotent():
    spdx = {"documentDescribes": ["SPDXRef-DOCUMENT"], "packages": [], "relationships": []}
    enrich(spdx, [("platforms", "1.1.0")])
    enrich(spdx, [("platforms", "1.1.0")])
    pkgs = [p for p in spdx["packages"] if p.get("name") == "platforms"]
    assert len(pkgs) == 1
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd tools && uv run --no-project --with pytest python -m pytest sbom_enrich_test.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'sbom_enrich'`

- [ ] **Step 3: Implement `tools/sbom_enrich.py`**

```python
#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Enrich an SPDX JSON SBOM with the direct MODULE.bazel bazel_dep closure.

Reads an SPDX 2.3 document (produced by syft over the release tarball) plus the
repo MODULE.bazel, and adds one SPDX package per direct `bazel_dep` (name +
version) with a DEPENDS_ON relationship from the document's root package — so
the SBOM reflects the Bazel dependency graph, not only file contents.

Usage: sbom_enrich.py <spdx.json> <MODULE.bazel>   (mutates <spdx.json> in place)
"""

import json
import re
import sys

# Matches `bazel_dep(name = "X", version = "Y" ...)`; dev_dependency entries
# (which list version before the dev flag) are included.
_BAZEL_DEP = re.compile(
    r'bazel_dep\(\s*name\s*=\s*"(?P<name>[^"]+)"\s*,\s*version\s*=\s*"(?P<version>[^"]+)"'
)


def parse_bazel_deps(module_text):
    """Returns [(name, version), ...] for each direct bazel_dep with a version."""
    return [(m.group("name"), m.group("version")) for m in _BAZEL_DEP.finditer(module_text)]


def enrich(spdx, deps):
    """Adds an SPDX package + DEPENDS_ON relationship per (name, version) dep."""
    describes = spdx.get("documentDescribes") or []
    root_id = describes[0] if describes else "SPDXRef-DOCUMENT"
    packages = spdx.setdefault("packages", [])
    relationships = spdx.setdefault("relationships", [])
    existing = {p.get("SPDXID") for p in packages}
    for name, version in deps:
        spdxid = "SPDXRef-Package-bazeldep-" + re.sub(r"[^A-Za-z0-9.-]", "-", name)
        if spdxid in existing:
            continue
        existing.add(spdxid)
        packages.append({
            "SPDXID": spdxid,
            "name": name,
            "versionInfo": version,
            "downloadLocation": "NOASSERTION",
            "filesAnalyzed": False,
            "externalRefs": [{
                "referenceCategory": "PACKAGE-MANAGER",
                "referenceType": "purl",
                "referenceLocator": "pkg:bazel/%s@%s" % (name, version),
            }],
        })
        relationships.append({
            "spdxElementId": root_id,
            "relationshipType": "DEPENDS_ON",
            "relatedSpdxElement": spdxid,
        })
    return spdx


def main(argv):
    if len(argv) != 3:
        sys.exit("usage: sbom_enrich.py <spdx.json> <MODULE.bazel>")
    spdx_path, module_path = argv[1], argv[2]
    with open(spdx_path) as f:
        spdx = json.load(f)
    with open(module_path) as f:
        deps = parse_bazel_deps(f.read())
    enrich(spdx, deps)
    with open(spdx_path, "w") as f:
        json.dump(spdx, f, indent=2)
        f.write("\n")
    print("enriched %s with %d bazel_dep package(s)" % (spdx_path, len(deps)))


if __name__ == "__main__":
    main(sys.argv)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd tools && uv run --no-project --with pytest python -m pytest sbom_enrich_test.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Create `tools/sbom_prep.sh`** (local convenience wrapper)

```bash
#!/usr/bin/env bash
# Local helper: generate an SPDX SBOM for the release source tarball and enrich
# it with the direct MODULE.bazel bazel_dep closure. Requires `syft` on PATH
# (https://github.com/anchore/syft). The CI release workflow instead uses
# anchore/sbom-action to produce the base SBOM, then runs tools/sbom_enrich.py.
#
# Usage: tools/sbom_prep.sh <tag>     e.g. tools/sbom_prep.sh v0.1.0
set -o errexit -o nounset -o pipefail

TAG="${1:?missing release tag (e.g. v0.1.0)}"
TARBALL="rules_elide-${TAG}.tar.gz"
SBOM="rules_elide-${TAG}.spdx.json"

if [ ! -f "${TARBALL}" ]; then
  echo "error: ${TARBALL} not found; run .github/workflows/release_prep.sh ${TAG} first" >&2
  exit 1
fi

syft scan "file:${TARBALL}" -o "spdx-json=${SBOM}"
python3 "$(dirname "$0")/sbom_enrich.py" "${SBOM}" MODULE.bazel
echo "wrote ${SBOM}"
```

- [ ] **Step 6: Make it executable + shellcheck**

Run:
```bash
chmod +x tools/sbom_prep.sh
shellcheck tools/sbom_prep.sh && echo "shellcheck ok"
```
Expected: `shellcheck ok` (no warnings)

- [ ] **Step 7: Commit**

```bash
git add tools/sbom_enrich.py tools/sbom_enrich_test.py tools/sbom_prep.sh
git commit -m "feat(release): SPDX SBOM bazel_dep enrichment helper + tests"
```

---

### Task 3: Orchestrated release workflow

**Files:**
- Modify (rewrite): `.github/workflows/release.yml`
- Delete: `.github/workflows/publish-to-bcr.yml`

**Interfaces:**
- Consumes: Task 1 config files; Task 2 `tools/sbom_enrich.py`; the existing `.github/workflows/release_prep.sh`; the `PUBLISH_TOKEN` secret; the `elide-dev/bazel-central-registry` fork.
- Produces: on a release PR merge — tag `vX.Y.Z`, a GitHub Release carrying `rules_elide-vX.Y.Z.tar.gz`, `…docs.tar.gz`, `…spdx.json`, Sigstore build-provenance + SBOM attestations, and a BCR PR.

- [ ] **Step 1: Rewrite `.github/workflows/release.yml`**

```yaml
name: release

on:
  push:
    branches: [main]

# Don't cancel an in-flight release.
concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false

permissions:
  contents: read

jobs:
  release-please:
    name: release-please
    runs-on: ubuntu-24.04
    permissions:
      contents: write
      pull-requests: write
    outputs:
      release_created: ${{ steps.rp.outputs.release_created }}
      tag_name: ${{ steps.rp.outputs.tag_name }}
    steps:
      - name: Harden the runner (Audit all outbound calls)
        uses: step-security/harden-runner@9af89fc71515a100421586dfdb3dc9c984fbf411  # v2.19.4
        with:
          egress-policy: audit
      - uses: googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7  # v5.0.0
        id: rp
        with:
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json

  assets:
    name: release assets + provenance
    needs: release-please
    if: needs.release-please.outputs.release_created == 'true'
    runs-on: ubuntu-24.04
    permissions:
      contents: write       # upload release assets
      id-token: write       # OIDC for Sigstore keyless signing
      attestations: write   # write the provenance/SBOM attestations
    env:
      TAG: ${{ needs.release-please.outputs.tag_name }}
      GH_TOKEN: ${{ github.token }}
    steps:
      - name: Harden the runner (Audit all outbound calls)
        uses: step-security/harden-runner@9af89fc71515a100421586dfdb3dc9c984fbf411  # v2.19.4
        with:
          egress-policy: audit
      - uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0  # v7.0.0
        with:
          ref: ${{ needs.release-please.outputs.tag_name }}
          fetch-depth: 0   # release_prep.sh runs `git archive <tag>`
      - name: Build release assets
        run: .github/workflows/release_prep.sh "$TAG" > usage_notes.md
      - name: Generate SPDX SBOM (syft)
        uses: anchore/sbom-action@e22c389904149dbc22b58101806040fa8d37a610  # v0.24.0
        with:
          file: rules_elide-${{ env.TAG }}.tar.gz
          format: spdx-json
          output-file: rules_elide-${{ env.TAG }}.spdx.json
          upload-artifact: false
      - name: Enrich SBOM with MODULE.bazel deps
        run: python3 tools/sbom_enrich.py "rules_elide-${TAG}.spdx.json" MODULE.bazel
      - name: Upload assets to the release
        run: |
          gh release upload "$TAG" \
            "rules_elide-${TAG}.tar.gz" \
            "rules_elide-${TAG}.docs.tar.gz" \
            "rules_elide-${TAG}.spdx.json" \
            --clobber
      - name: Append Bzlmod usage notes to the release body
        run: |
          gh release view "$TAG" --json body --jq .body > body.md
          printf '\n\n' >> body.md
          cat usage_notes.md >> body.md
          gh release edit "$TAG" --notes-file body.md
      - name: Attest build provenance (Sigstore, SLSA Build L2)
        uses: actions/attest-build-provenance@a2bbfa25375fe432b6a289bc6b6cd05ecd0c4c32  # v4.1.0
        with:
          subject-path: |
            rules_elide-${{ env.TAG }}.tar.gz
            rules_elide-${{ env.TAG }}.docs.tar.gz
            rules_elide-${{ env.TAG }}.spdx.json
      - name: Attest SBOM
        uses: actions/attest-sbom@c604332985a26aa8cf1bdc465b92731239ec6b9e  # v4.1.0
        with:
          subject-path: rules_elide-${{ env.TAG }}.tar.gz
          sbom-path: rules_elide-${{ env.TAG }}.spdx.json

  bcr:
    name: publish to BCR
    needs: [release-please, assets]
    if: needs.release-please.outputs.release_created == 'true'
    permissions:
      contents: write
      id-token: write
      attestations: write
    uses: bazel-contrib/publish-to-bcr/.github/workflows/publish.yaml@c316f1611511a40423572303f66c80bb30bfe2f8  # v1.4.1
    with:
      tag_name: ${{ needs.release-please.outputs.tag_name }}
      registry_fork: elide-dev/bazel-central-registry
    secrets:
      publish_token: ${{ secrets.PUBLISH_TOKEN }}
```

- [ ] **Step 2: Delete the now-folded-in standalone BCR workflow**

Run: `git rm .github/workflows/publish-to-bcr.yml`

- [ ] **Step 3: Validate the workflow with actionlint**

Run: `uv run --no-project --with pre-commit==4.6.0 pre-commit run actionlint --files .github/workflows/release.yml`
Expected: `Lint GitHub Actions workflow files....Passed`

- [ ] **Step 4: Sanity-check the asset pipeline locally** (the tag won't exist; use HEAD)

Run:
```bash
git tag v0.0.0-test
.github/workflows/release_prep.sh v0.0.0-test > /tmp/notes.md
ls -la rules_elide-v0.0.0-test.tar.gz rules_elide-v0.0.0-test.docs.tar.gz
python3 -c "import tarfile; tarfile.open('rules_elide-v0.0.0-test.tar.gz').getmembers() and print('tarball ok')"
git tag -d v0.0.0-test
rm -f rules_elide-v0.0.0-test.*
```
Expected: both archives listed, `tarball ok`.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "feat(release): orchestrated release-please -> assets+provenance -> BCR workflow

Fold publish-to-bcr into a single release.yml; add SBOM + Sigstore
build-provenance attestations (SLSA Build L2)."
```

---

### Task 4: Release documentation + final sweep

**Files:**
- Create: `RELEASING.md`
- Modify: `README.md` (add a short "Releases & provenance" pointer if a logical section exists; otherwise append one)

**Interfaces:**
- Consumes: nothing. Produces: human docs only.

- [ ] **Step 1: Create `RELEASING.md`**

```markdown
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
```

- [ ] **Step 2: Run the full pre-commit suite over all new/changed files**

Run:
```bash
uv run --no-project --with pre-commit==4.6.0 pre-commit run --files \
  release-please-config.json .release-please-manifest.json CHANGELOG.md \
  tools/sbom_enrich.py tools/sbom_enrich_test.py tools/sbom_prep.sh \
  .github/workflows/release.yml RELEASING.md README.md
```
Expected: all hooks `Passed`.

- [ ] **Step 3: Commit**

```bash
git add RELEASING.md README.md
git commit -m "docs(release): document the release flow and provenance verification"
```

---

## Notes for the implementer

- **SHAs:** use the exact pins in the Global Constraints table. If any needs a newer version, re-resolve with `gh api repos/<owner>/<repo>/commits/<tag> --jq .sha` and update the trailing `# vX.Y.Z` comment.
- **Do not** modify `.bcr/*`, `e2e/smoke/*`, or `.github/workflows/release_prep.sh` — they already match this flow.
- **`shellcheck`** and **`actionlint`** are provided by the repo's pre-commit hooks; if not on PATH, invoke them through `pre-commit run` as shown.
- The first real release (`v0.1.0`, when the seeded release PR is merged) is the end-to-end integration test; there is no way to fully exercise tag-triggered provenance/BCR locally.
- This implements **SLSA Build L2** (per the approved spec); L3 via `slsa-github-generator` is explicitly out of scope.
