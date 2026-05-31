#!/bin/sh
# Regenerate Markdown reference docs from .bzl sources via Stardoc.
set -eu
# POSIX sh lacks pipefail; bash provides it. Re-exec under bash when present.
if [ -z "${BASH_VERSION:-}" ] && command -v bash >/dev/null 2>&1; then
  exec bash -o errexit -o nounset -o pipefail "$0" "$@"
fi
[ -n "${BASH_VERSION:-}" ] && set -o pipefail

cd "$(dirname "$0")/.."

bazelisk build //docs:all_docs >/dev/null

for f in bazel-bin/docs/*.md; do
  out="docs/$(basename "$f")"
  # Pre-commit invariants: strip trailing whitespace per line,
  # collapse trailing newlines to exactly one (POSIX $() trims them).
  content=$(sed -e 's/[[:space:]]\+$//' "$f")
  printf '%s\n' "$content" > "$out"
  chmod 644 "$out"
done

echo "Regenerated $(ls bazel-bin/docs/*.md | wc -l) doc(s) under docs/."
