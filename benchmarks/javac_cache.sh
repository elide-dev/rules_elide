#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Benchmark the `elide javac --classpath-cache` delta (rules_elide
# //config/javac:classpath_cache). The cache lets a persistent javac worker
# reuse parsed classpath state across warm compiles instead of re-reading and
# re-indexing every dependency jar each request.
#
# IMPORTANT — what this shows: the cache's saving is dominated by *cold*
# classpath I/O (re-reading jars from disk). Once the OS page cache holds the
# classpath — the normal repeated-build case — re-indexing is cheap and the
# warm-steady-state delta measured here is near zero. The cache's real payoff is
# on cold / page-cache-evicted classpaths (large dep sets, memory-pressured CI),
# which this warm benchmark deliberately does not fake. Treat a ~parity result
# as expected on a warm box; measure the cold case by dropping the page cache.
#
# Workload: a trivial source compiled against a large, real classpath — the
# elide distribution's own `lib/*.jar` (derived from $ELIDE, ~180 jars / ~100MB;
# nothing hardcoded).
#
# Measured with hyperfine, each a fresh process per run:
#   cold        one-shot `elide javac` (fresh process + 1 compile)
#   cache OFF   persistent worker, N requests (re-indexes classpath each time)
#   cache ON    persistent worker, N requests, --classpath-cache (index once)
# warm/compile is the marginal (t[K]-t[1])/(K-1); the cache gain is off - on.
#
# Usage: ELIDE=/abs/path/to/elide benchmarks/javac_cache.sh [RUNS] [WARMUP] [K]

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ELIDE="${ELIDE:-elide}"
command -v "$ELIDE" >/dev/null 2>&1 || { echo "elide not found: $ELIDE" >&2; exit 2; }
command -v hyperfine >/dev/null 2>&1 || { echo "hyperfine required" >&2; exit 2; }
RUNS="${1:-10}"; WARMUP="${2:-2}"; K="${3:-8}"
GEN="$HERE/pgo/gen_workrequest.py"

DIST="$(dirname "$(dirname "$(readlink -f "$ELIDE")")")"
CP="$(find "$DIST/lib" -name '*.jar' 2>/dev/null | paste -sd:)"
[ -n "$CP" ] || { echo "no jars under $DIST/lib for a classpath" >&2; exit 2; }
NJARS="$(echo "$CP" | tr ':' '\n' | grep -c .)"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/javac-cache.XXXXXX")"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/out"
printf 'public class Hello { public static void main(String[] a) {} }\n' > "$WORK/Hello.java"

# Worker request streams: 1 and K requests, cache off and on (rotating outputs).
emit() { # $1=cache(0/1) $2=count $3=outfile
  : > "$3"
  local i extra=(); [ "$1" = 1 ] && extra=("--classpath-cache")
  for ((i = 1; i <= $2; i++)); do
    python3 "$GEN" "--jar" "$WORK/out/c$1_$i.jar" "${extra[@]}" "--" \
      -classpath "$CP" "$WORK/Hello.java" >> "$3"
  done
}
emit 0 1 "$WORK/off_1.bin"; emit 0 "$K" "$WORK/off_K.bin"
emit 1 1 "$WORK/on_1.bin";  emit 1 "$K" "$WORK/on_K.bin"

echo "elide: $("$ELIDE" --version 2>/dev/null | head -1)  |  classpath: $NJARS jars  |  RUNS=$RUNS K=$K"
hyperfine --warmup "$WARMUP" --runs "$RUNS" --export-json "$WORK/r.json" \
  -n "one-shot (cold)"          "$ELIDE javac --jar $WORK/out/os.jar -- -classpath $CP $WORK/Hello.java" \
  -n "worker cache OFF (1-req)" "$ELIDE javac --persistent_worker < $WORK/off_1.bin" \
  -n "worker cache OFF (${K}-req)" "$ELIDE javac --persistent_worker < $WORK/off_K.bin" \
  -n "worker cache ON  (1-req)" "$ELIDE javac --persistent_worker < $WORK/on_1.bin" \
  -n "worker cache ON  (${K}-req)" "$ELIDE javac --persistent_worker < $WORK/on_K.bin"

echo
echo "=== warm per-compile (marginal) — the --classpath-cache gain ==="
python3 - "$WORK/r.json" "$K" <<'PY'
import json, sys
res = {r["command"]: r["mean"] * 1000 for r in json.load(open(sys.argv[1]))["results"]}
K = int(sys.argv[2])
def warm(one, kk): return (res[kk] - res[one]) / (K - 1)
off = warm("worker cache OFF (1-req)", "worker cache OFF (%d-req)" % K)
on = warm("worker cache ON  (1-req)", "worker cache ON  (%d-req)" % K)
print("  cold one-shot          %7.1f ms" % res["one-shot (cold)"])
print("  warm/compile cache OFF %7.1f ms" % off)
print("  warm/compile cache ON  %7.1f ms" % on)
if on > 0:
    print("  → cache saves %.1f ms/compile (%.2fx faster warm)" % (off - on, off / on))
PY
