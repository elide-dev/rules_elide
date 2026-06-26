#!/usr/bin/env bash
# Release-asset preparer. Called from the bazel-contrib release_ruleset
# reusable workflow with a single argument: the release tag (e.g. v1.2.3).
#
# Emits:
#   - rules_elide-vX.Y.Z.tar.gz         source archive (respects .gitattributes)
#   - rules_elide-vX.Y.Z.docs.tar.gz    Stardoc-rendered Markdown reference
#   - rules_elide-vX.Y.Z.spdx.json      SPDX SBOM (syft + MODULE.bazel deps)
#
# Writes release notes to stdout. ALL other tool output must go to stderr, since
# release_ruleset captures this script's stdout as the release notes.
set -o errexit -o nounset -o pipefail

TAG="${1:?missing release tag}"
VERSION="${TAG#v}"
PREFIX="rules_elide-${VERSION}"
SRC_ARCHIVE="rules_elide-${TAG}.tar.gz"
DOCS_ARCHIVE="rules_elide-${TAG}.docs.tar.gz"
SBOM="rules_elide-${TAG}.spdx.json"

# Source archive (respects .gitattributes export-ignore).
git archive --format=tar.gz --prefix="${PREFIX}/" -o "${SRC_ARCHIVE}" "${TAG}"

# Docs archive (Stardoc-rendered Markdown).
docs_stage="$(mktemp -d)"
trap 'rm -rf "${docs_stage}"' EXIT
mkdir -p "${docs_stage}/${PREFIX}/docs"
cp docs/*.md "${docs_stage}/${PREFIX}/docs/"
(cd "${docs_stage}" && tar -cz -f "${OLDPWD}/${DOCS_ARCHIVE}" "${PREFIX}")

# SPDX SBOM over the source archive, enriched with the MODULE.bazel dep closure.
# syft is fetched as a pinned release binary and checksum-verified against the
# release's checksums.txt — no remote installer script is piped to a shell. Tool
# output goes to stderr so it never pollutes the release notes on stdout.
SYFT_VERSION="1.45.1"
syft_dir="$(mktemp -d)"
syft_base="https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}"
syft_tgz="syft_${SYFT_VERSION}_linux_amd64.tar.gz"
(
  cd "${syft_dir}"
  curl -fsSL -o "${syft_tgz}" "${syft_base}/${syft_tgz}"
  curl -fsSL -o checksums.txt "${syft_base}/syft_${SYFT_VERSION}_checksums.txt"
  grep " ${syft_tgz}\$" checksums.txt | sha256sum -c -
  tar -xzf "${syft_tgz}" syft
) 1>&2
"${syft_dir}/syft" scan "file:${SRC_ARCHIVE}" -o "spdx-json=${SBOM}" 1>&2
python3 tools/sbom_enrich.py "${SBOM}" MODULE.bazel 1>&2

SHA256="$(openssl dgst -sha256 -hex "${SRC_ARCHIVE}" | awk '{print $NF}')"
INTEGRITY="sha256-$(openssl dgst -binary -sha256 "${SRC_ARCHIVE}" | base64)"

cat <<EOF
## Using Bzlmod (Bazel 7+)

\`\`\`starlark
bazel_dep(name = "rules_elide", version = "${VERSION}")
\`\`\`

### Pinned by integrity

\`\`\`starlark
bazel_dep(name = "rules_elide", version = "${VERSION}")
single_version_override(
    module_name = "rules_elide",
    integrity = "${INTEGRITY}",
)
\`\`\`

Archives:
- Source: \`${SRC_ARCHIVE}\`
- Docs:   \`${DOCS_ARCHIVE}\`
- SBOM:   \`${SBOM}\` (SPDX)

SHA-256 (source): \`${SHA256}\`
EOF
