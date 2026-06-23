#!/usr/bin/env bash
# Three-way benchmark suite for screenshots, driven by hyperfine:
#
#   baseline      vanilla rules_java / rules_kotlin
#   elide         elide rules, persistent workers OFF
#                 (one-shot `elide <tool> -- <args>` process per target)
#   elide+worker  elide rules, persistent workers ON (warm process reused)
#
# Run under two regimes:
#   cold : `bazel clean` before each run — full from-scratch build. `clean`
#          resets the worker pool, so even elide+worker spawns a fresh worker;
#          this isolates elide-vs-baseline (workers can't help a single build).
#   warm : edit one source and rebuild WITHOUT cleaning — the incremental
#          dev/CI inner loop. elide+worker reuses its warm compiler process, so
#          this is where persistent workers pay off (most visibly for Kotlin,
#          whose compiler has the heaviest startup).
#
# Each (language, regime) is one hyperfine invocation comparing the three
# conditions, so you get four clean 3-bar comparisons. hyperfine runs a
# command's runs consecutively, so the one `use_workers` flag flip per command
# (which discards Bazel's analysis cache) lands in --warmup, not the timed runs.
#
# Why no wide "many small targets" regime: elide's worker is singleplex, so
# Bazel caps it at --worker_max_instances (default 4) while the workers-off
# one-shot path uses all cores. On wide parallel fan-out that serialization
# outweighs the startup savings (workers can be slower), so it is a poor
# demonstration of the worker win — which is about warm reuse, not fan-out.
#
# Note: the `elide` (workers-off) condition uses the one-shot `--` form via
# `--@rules_elide//elide:use_workers=false`. Do NOT instead disable workers with
# `--worker_max_instances=0`/`--strategy=local`: that hits the broken upstream
# fallback (WHIPLASH #994).
#
# Requires: hyperfine, bazelisk (or $BAZELISK).
#
# Usage:  ./bench_suite.sh [N] [RUNS] [WARMUP]
#   N      sources per language (default 50)
#   RUNS   measured runs per condition (default 10)
#   WARMUP warmup runs per condition (default 3)
set -o errexit -o nounset -o pipefail

N="${1:-50}"
RUNS="${2:-10}"
WARMUP="${3:-3}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "${ROOT}"

command -v hyperfine >/dev/null 2>&1 || {
  echo "error: hyperfine not found — see https://github.com/sharkdp/hyperfine" >&2
  exit 1
}
BAZEL="${BAZELISK:-bazelisk}"
WORKER_FLAG="--@rules_elide//elide:use_workers"

./gen.sh "${N}" >/dev/null
OUT="${ROOT}/results"
mkdir -p "${OUT}"

# Prime one-time costs (elide CDN download, remote JDK, repo fetch, first
# analysis under each flag value) so the first measured run isn't skewed.
"${BAZEL}" build //:vanilla_java_lib //:vanilla_kotlin_lib >/dev/null 2>&1 || true
"${BAZEL}" build //:elide_java_lib //:elide_kotlin_lib "${WORKER_FLAG}=false" >/dev/null 2>&1 || true
"${BAZEL}" build //:elide_java_lib //:elide_kotlin_lib "${WORKER_FLAG}=true" >/dev/null 2>&1 || true

# run_suite LANG REGIME SRC
#   REGIME in {cold, warm}; SRC is the file edited in the warm regime.
run_suite() {
  local lang="$1" regime="$2" src="$3"
  local prepare tag
  if [ "${regime}" = "cold" ]; then
    prepare="${BAZEL} clean >/dev/null 2>&1"
  else  # warm
    prepare="printf '\n// bench_suite edit\n' >> '${src}'"
  fi
  tag="${lang}_${regime}"
  echo
  echo "=== ${lang} / ${regime} : baseline vs elide vs elide+worker ==="
  hyperfine \
    --warmup "${WARMUP}" --runs "${RUNS}" \
    --prepare "${prepare}" \
    --command-name "baseline"     "${BAZEL} build //:vanilla_${lang}_lib >/dev/null 2>&1" \
    --command-name "elide"        "${BAZEL} build //:elide_${lang}_lib ${WORKER_FLAG}=false >/dev/null 2>&1" \
    --command-name "elide+worker" "${BAZEL} build //:elide_${lang}_lib ${WORKER_FLAG}=true >/dev/null 2>&1" \
    --export-markdown "${OUT}/${tag}.md" \
    --export-json "${OUT}/${tag}.json"
}

JAVA_SRC="${ROOT}/sources/java/sample/JavaClass1.java"
KOTLIN_SRC="${ROOT}/sources/kotlin/sample/KotlinClass1.kt"

run_suite java   cold "${JAVA_SRC}"
run_suite java   warm "${JAVA_SRC}"
run_suite kotlin cold "${KOTLIN_SRC}"
run_suite kotlin warm "${KOTLIN_SRC}"

# Regenerate pristine sources (warm runs appended edit markers).
./gen.sh "${N}" >/dev/null

echo
echo "Exports written under: ${OUT}/  (per-regime .md tables and .json)"
