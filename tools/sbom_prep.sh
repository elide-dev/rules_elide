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
