#!/usr/bin/env bash
# Release-asset preparer. Called from the bazel-contrib release_ruleset
# reusable workflow with a single argument: the release tag (e.g. v1.2.3).
#
# Emits a gzipped source archive and writes release notes to stdout.
set -o errexit -o nounset -o pipefail

TAG="${1:?missing release tag}"
VERSION="${TAG#v}"
PREFIX="rules_elide-${VERSION}"
ARCHIVE="rules_elide-${TAG}.tar.gz"

git archive --format=tar.gz --prefix="${PREFIX}/" -o "${ARCHIVE}" "${TAG}"

SHA256="$(openssl dgst -sha256 -hex "${ARCHIVE}" | awk '{print $NF}')"
INTEGRITY="sha256-$(openssl dgst -binary -sha256 "${ARCHIVE}" | base64)"

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

SHA-256: \`${SHA256}\`
EOF
