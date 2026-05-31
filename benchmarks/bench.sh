#!/usr/bin/env bash
# Wall-clock benchmark of rules_elide vs canonical rules_java / rules_kotlin
# on the same set of generated sources. Scoped to the benchmarks/ workspace;
# does not touch any other Bazel state.
#
# Usage:  ./bench.sh [N] [RUNS]
#   N    : number of source files of each language (default 50)
#   RUNS : measured runs per target (default 3); cache is cleared each run.
set -o errexit -o nounset -o pipefail

N="${1:-50}"
RUNS="${2:-3}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "${ROOT}"

./gen.sh "${N}" >/dev/null

BAZEL="${BAZELISK:-bazelisk}"

measure() {
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

echo "Benchmark: ${N} java + ${N} kotlin sources, ${RUNS} runs per target"
echo "============================================================"
echo

measure "//:vanilla_java_lib"   "vanilla_java"
measure "//:elide_java_lib"     "elide_java"
measure "//:vanilla_kotlin_lib" "vanilla_kotlin"
measure "//:elide_kotlin_lib"   "elide_kotlin"
