#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Regression guard for WHIPLASH #1113.
#
# Bug: one-shot `elide kotlinc --incremental --incremental-cache-dir <dir>`
# spins in a runaway loop (one thread ~100% CPU, RSS climbing) on the SECOND
# invocation whenever the **source file is not located under the current working
# directory**. Cold compile and source-under-CWD reuse are fine; the persistent-
# worker path is fine. Root cause appears to be IC source-root relativization
# against the CWD (cold also prints "Duplicate source root: <abs path>").
#
# This test reproduces the trigger: it runs `elide` from a directory that is NOT
# an ancestor of the source, then does a reuse compile under a hard timeout.
#
#   - reuse completes  -> the bug is FIXED            -> exit 0 (PASS)
#   - reuse times out  -> the bug still reproduces    -> exit 1 (EXPECTED FAIL
#                                                        until #1113 lands)
#
# Usage:  ELIDE=/path/to/elide ./wl1113_regression.sh   (or: ./wl1113_regression.sh /path/to/elide)

set -uo pipefail

ELIDE="${ELIDE:-${1:-elide}}"
command -v "$ELIDE" >/dev/null 2>&1 || { echo "elide binary not found: $ELIDE" >&2; exit 2; }

TIMEOUT="${TIMEOUT:-25}"   # seconds before declaring the reuse hung

# Two sibling temp dirs: SRC holds the source/cache/out; RUN is the CWD and is
# deliberately NOT an ancestor of SRC, so the source is outside the CWD subtree.
BASE="$(mktemp -d "${TMPDIR:-/tmp}/wl1113.XXXXXX")"
SRC="$BASE/work"; RUN="$BASE/run"
mkdir -p "$SRC/out" "$SRC/cache" "$RUN"
trap 'pkill -9 -f "$SRC/cache" 2>/dev/null; rm -rf "$BASE"' EXIT

printf 'package ic\nobject M { fun f(x: Int): Int = x * x }\n' > "$SRC/M.kt"

echo "WHIPLASH#1113 regression  (elide: $("$ELIDE" --version 2>/dev/null | head -1))"
echo "  CWD=$RUN   source=$SRC/M.kt  (source NOT under CWD)"

# Cold compile (expected fine).
if ! ( cd "$RUN" && "$ELIDE" kotlinc --incremental --incremental-cache-dir "$SRC/cache" \
        -- -d "$SRC/out" "$SRC/M.kt" ) >/dev/null 2>&1; then
  echo "  UNEXPECTED: cold compile failed — environment problem, not #1113" >&2
  exit 2
fi

# Reuse compile under a hard timeout. SIGKILL so a signal-masking loop can't survive.
start=$(date +%s%3N)
( cd "$RUN" && timeout -s KILL "$TIMEOUT" "$ELIDE" kotlinc --incremental \
    --incremental-cache-dir "$SRC/cache" -- -d "$SRC/out" "$SRC/M.kt" ) >/dev/null 2>&1
rc=$?
elapsed=$(( $(date +%s%3N) - start ))

if [ "$rc" -eq 137 ] || [ "$rc" -eq 124 ]; then
  echo "  ✗ reuse HUNG (killed after ${TIMEOUT}s) — #1113 still reproduces"
  echo "  EXPECTED FAIL until WHIPLASH#1113 is fixed; this turns green when it is."
  exit 1
elif [ "$rc" -ne 0 ]; then
  echo "  ✗ reuse failed with exit $rc (not a hang) — investigate" >&2
  exit 1
else
  echo "  ✓ reuse completed in ${elapsed}ms — #1113 appears FIXED"
  exit 0
fi
