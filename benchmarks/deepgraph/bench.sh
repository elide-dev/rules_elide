#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Deep-graph benchmark: generates the layered fixture (gen.py) and measures the
# graph-scale behaviors a trivial fixture can't show —
#   * clean-build wall-clock (critical-path depth), kotlin and java
#   * cross-target ABI compile-avoidance: edit a method BODY in `core` and count
#     how many compile actions re-run. With avoidance only `core` rebuilds (~2-3
#     actions); without, the reverse-dependency closure cascades. (Java prunes;
#     Kotlin currently cascades — the run_ijar-not-body-stable bug.)
#
# Builds via the generated workspace's elide toolchain (the local `elide.use`
# binary), so it reflects whatever the `current` symlink points at.
#
# Usage: ELIDE=/abs/path/to/elide benchmarks/deepgraph/bench.sh [LAYERS] [WIDTH]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ELIDE="${ELIDE:-elide}"; command -v "$ELIDE" >/dev/null 2>&1 || { echo "elide not found: $ELIDE" >&2; exit 2; }
LAYERS="${1:-16}"; WIDTH="${2:-32}"
WS="$HERE/ws"

python3 "$HERE/gen.py" --elide "$ELIDE" --layers "$LAYERS" --width "$WIDTH" --langs kotlin,java --out "$WS" >/dev/null
cd "$WS"
actions() { bazelisk build "$@" 2>&1 | grep -oE "[0-9]+ total action" | grep -oE "^[0-9]+" | tail -1; }
clean_build() { bazelisk shutdown >/dev/null 2>&1; local s; s=$(date +%s%3N); bazelisk build "$1" >/dev/null 2>&1; echo $(($(date +%s%3N)-s)); }

echo "elide: $("$ELIDE" --version 2>/dev/null | head -1)  |  ${LAYERS} layers x ${WIDTH} width (~$((LAYERS*WIDTH)) files/lang)"
echo "  clean build //kotlin/... : $(clean_build //kotlin/...) ms"
echo "  clean build //java/...   : $(clean_build //java/...) ms"

echo "=== cross-target ABI avoidance: body edit in core -> how many compiles re-run? ==="
bazelisk build //kotlin/... //java/... >/dev/null 2>&1
sed -i 's/fun base(n: Int): Int = n \* 2/fun base(n: Int): Int = n * 3/' kotlin/core/Box.kt
echo "  kotlin core body edit: $(actions //kotlin/...) reruns   (~2-3 = avoidance; ~$((LAYERS+2)) = cascade)"
sed -i 's/fun base(n: Int): Int = n \* 3/fun base(n: Int): Int = n * 2/' kotlin/core/Box.kt
sed -i 's/return n\*2;/return n*2+0;/' java/core/Util.java
echo "  java   core body edit: $(actions //java/...) reruns"
sed -i 's/return n\*2+0;/return n*2;/' java/core/Util.java
bazelisk shutdown >/dev/null 2>&1
