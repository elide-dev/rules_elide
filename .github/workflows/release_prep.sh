#!/usr/bin/env bash
# Release-asset preparer. Called from the bazel-contrib release_ruleset
# reusable workflow with a single argument: the release tag (e.g. v1.2.3).
#
# Emits:
#   - rules_elide-vX.Y.Z.tar.gz         source archive (respects .gitattributes)
#   - rules_elide-vX.Y.Z.docs.tar.gz    Stardoc-rendered Markdown reference
#
# Writes release notes to stdout.
set -o errexit -o nounset -o pipefail

TAG="${1:?missing release tag}"
VERSION="${TAG#v}"
PREFIX="rules_elide-${VERSION}"
SRC_ARCHIVE="rules_elide-${TAG}.tar.gz"
DOCS_ARCHIVE="rules_elide-${TAG}.docs.tar.gz"

# Source archive (respects .gitattributes export-ignore).
git archive --format=tar.gz --prefix="${PREFIX}/" -o "${SRC_ARCHIVE}" "${TAG}"

# Docs archive (Stardoc-rendered Markdown).
docs_stage="$(mktemp -d)"
trap 'rm -rf "${docs_stage}"' EXIT
mkdir -p "${docs_stage}/${PREFIX}/docs"
cp docs/*.md "${docs_stage}/${PREFIX}/docs/"
(cd "${docs_stage}" && tar -cz -f "${OLDPWD}/${DOCS_ARCHIVE}" "${PREFIX}")

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

SHA-256 (source): \`${SHA256}\`
EOF
