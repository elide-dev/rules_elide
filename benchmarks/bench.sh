#!/usr/bin/env bash
# Wall-clock benchmark of rules_elide vs canonical rules_java / rules_kotlin
# on the same set of generated sources. Scoped to the benchmarks/ workspace;
# does not touch any other Bazel state.
#
# This is the lightweight (no-hyperfine) timer; for the full three-way suite
# (baseline vs elide vs elide+worker) prefer `bench_suite.sh`.
#
# Two regimes are measured:
#   cold  : `bazel clean` before each run — full from-scratch build (worst
#           case; rare in CI).
#   warm  : one warm-up build, then each measured run edits a single source and
#           rebuilds WITHOUT cleaning — the steady-state inner dev / CI loop.
#
# Note: the elide compile actions run as persistent workers by default. Workers
# are roughly wall-clock-neutral for elide (it is a native image with ~12 ms
# startup, so there is little to amortize) — the win measured here is elide vs
# the vanilla baselines, not workers. To run elide without workers use
# `--@rules_elide//elide:use_workers=false`; do NOT use
# `--worker_max_instances=0`/`--strategy=local` (broken upstream, WHIPLASH #994).
#
# Usage:  ./bench.sh [N] [RUNS]
#   N    : number of source files of each language (default 50)
#   RUNS : measured runs per target per regime (default 3)
set -o errexit -o nounset -o pipefail

N="${1:-50}"
RUNS="${2:-3}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "${ROOT}"

./gen.sh "${N}" >/dev/null

BAZEL="${BAZELISK:-bazelisk}"

JAVA_SRC="${ROOT}/sources/java/sample/JavaClass1.java"
KOTLIN_SRC="${ROOT}/sources/kotlin/sample/KotlinClass1.kt"

# cold: clean before every run, so each elide compile gets a fresh (cold)
# persistent worker. Captures the from-scratch warm-up cost.
measure_cold() {
  local target="$1"
  local label="$2"
  local total_ns=0
  for i in $(seq 1 "${RUNS}"); do
    "${BAZEL}" clean >/dev/null 2>&1
    local start_ns end_ns
    start_ns=$(date +%s%N)
    "${BAZEL}" build "${target}" >/dev/null 2>&1
    end_ns=$(date +%s%N)
    local elapsed_ns=$(( end_ns - start_ns ))
    total_ns=$(( total_ns + elapsed_ns ))
    printf "  [%s] run %d: %.2fs\n" "${label}" "${i}" "$(awk "BEGIN{print ${elapsed_ns}/1e9}")"
  done
  local avg_s
  avg_s=$(awk "BEGIN{print ${total_ns}/${RUNS}/1e9}")
  printf "  [%s] AVERAGE over %d runs: %.2fs\n\n" "${label}" "${RUNS}" "${avg_s}"
}

# warm: warm-up build (spawns + warms the worker), then each run edits one
# source and rebuilds without cleaning. The worker is reused warm across runs.
measure_warm() {
  local target="$1"
  local label="$2"
  local src="$3"
  "${BAZEL}" clean >/dev/null 2>&1
  "${BAZEL}" build "${target}" >/dev/null 2>&1  # warm-up (discarded)
  local total_ns=0
  for i in $(seq 1 "${RUNS}"); do
    # Content edit (not just mtime) so Bazel re-runs the compile action; a
    # trailing line comment is valid in both Java and Kotlin.
    printf '\n// bench warm edit %d\n' "${i}" >> "${src}"
    local start_ns end_ns
    start_ns=$(date +%s%N)
    "${BAZEL}" build "${target}" >/dev/null 2>&1
    end_ns=$(date +%s%N)
    local elapsed_ns=$(( end_ns - start_ns ))
    total_ns=$(( total_ns + elapsed_ns ))
    printf "  [%s] run %d: %.2fs\n" "${label}" "${i}" "$(awk "BEGIN{print ${elapsed_ns}/1e9}")"
  done
  local avg_s
  avg_s=$(awk "BEGIN{print ${total_ns}/${RUNS}/1e9}")
  printf "  [%s] AVERAGE over %d runs: %.2fs\n\n" "${label}" "${RUNS}" "${avg_s}"
}

echo "Benchmark: ${N} java + ${N} kotlin sources, ${RUNS} runs per target"
echo "============================================================"
echo
echo "-- cold (clean before each run; fresh worker per run) ------"
echo
measure_cold "//:vanilla_java_lib"   "vanilla_java"
measure_cold "//:elide_java_lib"     "elide_java"
measure_cold "//:vanilla_kotlin_lib" "vanilla_kotlin"
measure_cold "//:elide_kotlin_lib"   "elide_kotlin"

echo "-- warm (persistent worker reused across incremental edits) -"
echo
measure_warm "//:vanilla_java_lib"   "vanilla_java"   "${JAVA_SRC}"
measure_warm "//:elide_java_lib"     "elide_java"     "${JAVA_SRC}"
measure_warm "//:vanilla_kotlin_lib" "vanilla_kotlin" "${KOTLIN_SRC}"
measure_warm "//:elide_kotlin_lib"   "elide_kotlin"   "${KOTLIN_SRC}"

# Regenerate pristine sources (warm runs appended edit markers).
./gen.sh "${N}" >/dev/null
