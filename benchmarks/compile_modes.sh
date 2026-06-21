#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Compiler-mode microbenchmark for the Elide kotlinc, over the 50-file
# self-contained `sources/kotlin/sample` workload. Measures, with hyperfine,
# the two modes the spec cares about — full compile and Karbine (`--abi-only`)
# — each cold and warm:
#
#   cold  = a fresh process per compile (elide's ~12ms native-image startup +
#           one compile). one-shot `elide kotlinc` and a worker serving a single
#           request both measure this (the latter adds worker-protocol setup).
#   warm  = the marginal cost of an additional compile on an already-warm
#           persistent worker, isolated as (t[K requests] - t[1 request])/(K-1).
#
# Unlike bench_suite.sh (whole-build Bazel wall-clock), this isolates the
# compiler itself. Each worker request targets a distinct output dir so no
# incremental short-circuit hides real compile work.
#
# Usage: ELIDE=/abs/path/to/elide benchmarks/compile_modes.sh [RUNS] [WARMUP] [K]

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ELIDE="${ELIDE:-elide}"
command -v "$ELIDE" >/dev/null 2>&1 || { echo "elide not found: $ELIDE" >&2; exit 2; }
command -v hyperfine >/dev/null 2>&1 || { echo "hyperfine required" >&2; exit 2; }
RUNS="${1:-10}"; WARMUP="${2:-2}"; K="${3:-10}"

SAMPLE="$HERE/sources/kotlin/sample"
mapfile -t SRCS < <(ls "$SAMPLE"/*.kt)
SRCS_STR="${SRCS[*]}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/compile-modes.XXXXXX")"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/o"
gen() { python3 "$HERE/pgo/gen_workrequest.py" "$@"; }

# 1-request and K-request streams (rotating output dirs), for full + abi modes.
gen "--" "-d" "$WORK/o/f1" "${SRCS[@]}" > "$WORK/full_1.bin"
gen "--abi-only" "--" "-d" "$WORK/o/a1" "${SRCS[@]}" > "$WORK/abi_1.bin"
: > "$WORK/full_K.bin"; : > "$WORK/abi_K.bin"
for ((i = 1; i <= K; i++)); do
  gen "--" "-d" "$WORK/o/fK$i" "${SRCS[@]}" >> "$WORK/full_K.bin"
  gen "--abi-only" "--" "-d" "$WORK/o/aK$i" "${SRCS[@]}" >> "$WORK/abi_K.bin"
done

echo "elide: $("$ELIDE" --version 2>/dev/null | head -1)  |  ${#SRCS[@]} files  |  RUNS=$RUNS K=$K"
hyperfine --warmup "$WARMUP" --runs "$RUNS" --export-json "$WORK/r.json" \
  -n "full:    one-shot (cold)"     "$ELIDE kotlinc -- -d $WORK/o/os $SRCS_STR" \
  -n "full:    worker 1-req (cold)" "$ELIDE kotlinc --persistent_worker < $WORK/full_1.bin" \
  -n "full:    worker ${K}-req"     "$ELIDE kotlinc --persistent_worker < $WORK/full_K.bin" \
  -n "karbine: one-shot (cold)"     "$ELIDE kotlinc --abi-only -- -d $WORK/o/aos $SRCS_STR" \
  -n "karbine: worker 1-req (cold)" "$ELIDE kotlinc --persistent_worker < $WORK/abi_1.bin" \
  -n "karbine: worker ${K}-req"     "$ELIDE kotlinc --persistent_worker < $WORK/abi_K.bin"

echo
echo "=== cold vs warm (derived; warm = marginal per-compile on a warm worker) ==="
python3 - "$WORK/r.json" "$K" <<'PY'
import json, sys
res = {r["command"]: r["mean"] * 1000 for r in json.load(open(sys.argv[1]))["results"]}
K = int(sys.argv[2])
def warm(one, kk): return (res[kk] - res[one]) / (K - 1)
for mode, one_shot, w1, wK in [
    ("full   ", "full:    one-shot (cold)", "full:    worker 1-req (cold)", "full:    worker %d-req" % K),
    ("karbine", "karbine: one-shot (cold)", "karbine: worker 1-req (cold)", "karbine: worker %d-req" % K),
]:
    print("  %s  cold one-shot %7.1f ms | cold worker %7.1f ms | warm/compile %7.1f ms"
          % (mode, res[one_shot], res[w1], warm(w1, wK)))
PY
