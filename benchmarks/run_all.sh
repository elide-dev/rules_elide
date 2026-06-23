#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# One-shot driver for the full rules_elide benchmark suite. Delegates to the
# individual benchmark scripts (no logic duplicated here) and runs them in a
# sensible order, each clearly sectioned.
#
# Sections (pass names to run a subset; default: all but pgo):
#   modes        compile_modes.sh   — kotlinc full vs Karbine, cold vs warm
#   incremental  incremental.sh     — kotlinc IC: full vs 1-file-edit rebuild
#   javac        javac_cache.sh     — javac --classpath-cache delta
#   deepgraph    deepgraph/bench.sh — clean-build depth + ABI compile-avoidance
#   suite        bench_suite.sh     — Bazel 3-way: baseline vs elide vs +worker
#   pgo          pgo/collect.sh     — PGO profiles (needs a --pgo-instrument build)
#
# Usage:
#   ELIDE=/abs/path/to/elide benchmarks/run_all.sh                 # all but pgo
#   ELIDE=...                 benchmarks/run_all.sh modes incremental
#   ELIDE=...                 benchmarks/run_all.sh pgo             # opt-in
#
# The Bazel sections (deepgraph, suite) build through their workspace's elide
# toolchain — point its `elide.use(local_path=...)` at the same binary as $ELIDE
# (the `current` symlink already does this in this checkout).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ELIDE="${ELIDE:-elide}"
command -v "$ELIDE" >/dev/null 2>&1 || { echo "elide not found (set ELIDE=...): $ELIDE" >&2; exit 2; }
command -v hyperfine >/dev/null 2>&1 || echo "WARN: hyperfine missing — 'modes'/'javac' will fail" >&2
export ELIDE

SECTIONS=("$@"); [ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(modes incremental javac deepgraph suite)
has() { local s; for s in "${SECTIONS[@]}"; do [ "$s" = "$1" ] && return 0; done; return 1; }
hr() { printf '\n========== %s ==========\n' "$1"; }
rc=0
run() { "$@" || { echo "  (section failed: $*)" >&2; rc=1; }; }

echo "rules_elide benchmark suite  |  elide: $("$ELIDE" --version 2>/dev/null | head -1)"
echo "sections: ${SECTIONS[*]}"

has modes       && { hr "compile modes (kotlinc full vs Karbine, cold/warm)";   run "$HERE/compile_modes.sh"; }
has incremental && { hr "incremental (kotlinc full vs 1-file-edit IC rebuild)";  run "$HERE/incremental.sh"; }
has javac       && { hr "javac classpath-cache";                                 run "$HERE/javac_cache.sh"; }
has deepgraph   && { hr "deep graph (clean-build depth + ABI compile-avoidance)"; run "$HERE/deepgraph/bench.sh"; }
has suite       && { hr "Bazel 3-way (baseline vs elide vs elide+worker, cold/warm)"; run "$HERE/bench_suite.sh"; }
has pgo         && { hr "PGO profile collection"; run "$HERE/pgo/collect.sh"; }

hr "done"; exit $rc
