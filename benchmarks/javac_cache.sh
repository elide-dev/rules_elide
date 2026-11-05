#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Benchmark the `elide javac --classpath-cache` delta (rules_elide
# //config/javac:classpath_cache). The cache lets a persistent javac worker
# reuse parsed classpath state across warm compiles instead of re-reading and
# re-indexing every dependency jar each request.
#
# This isolates repeated compilation against the distribution's jars. It does
# not predict application performance or cold-disk behavior. Both cache modes
# disable annotation processing and provide input digests, as required for reuse.
# Older versions of this benchmark omitted both prerequisites, so their claimed
# cache comparisons did not establish cache behavior.
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
# Set RESULT_JSON to retain hyperfine raw samples after the temporary workspace is removed.
# Usage: ELIDE=/abs/path/to/elide benchmarks/javac_cache.sh [RUNS] [WARMUP] [K]

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ELIDE="${ELIDE:-elide}"
command -v "$ELIDE" >/dev/null 2>&1 || { echo "elide not found: $ELIDE" >&2; exit 2; }
command -v hyperfine >/dev/null 2>&1 || { echo "hyperfine required" >&2; exit 2; }
RUNS="${1:-10}"; WARMUP="${2:-2}"; K="${3:-8}"
GEN="$HERE/pgo/gen_workrequest.py"
(( K > 1 )) || { echo "K must be greater than 1" >&2; exit 2; }

DIST="$(dirname "$(dirname "$(readlink -f "$ELIDE")")")"
CP="$(find "$DIST/lib" -name '*.jar' 2>/dev/null | paste -sd:)"
[ -n "$CP" ] || { echo "no jars under $DIST/lib for a classpath" >&2; exit 2; }
NJARS="$(echo "$CP" | tr ':' '\n' | grep -c .)"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/javac-cache.XXXXXX")"; trap 'rm -rf "$WORK"' EXIT
RESULT_JSON="${RESULT_JSON:-$WORK/r.json}"
mkdir -p "$WORK/out"
printf 'public class Hello { public kotlin.Unit value() { return kotlin.Unit.INSTANCE; } }\n' > "$WORK/Hello.java"

# Attach content digests using exactly the paths spelled in the compiler argv.
python3 - "$CP" "$WORK/Hello.java" "$WORK/inputs.json" <<'PYINPUTS'
import json, os, pathlib, sys
pathlib.Path(sys.argv[3]).write_text(json.dumps(sys.argv[1].split(os.pathsep) + [sys.argv[2]]))
PYINPUTS

# Worker request streams: 1 and K requests, cache off and on (rotating outputs).
emit() { # $1=cache(0/1) $2=count $3=outfile
  : > "$3"
  local i extra=(); [ "$1" = 1 ] && extra=("--classpath-cache")
  for ((i = 1; i <= $2; i++)); do
    python3 "$GEN" --inputs-json "$WORK/inputs.json" -- "--jar" "$WORK/out/c$1_$i.jar" "${extra[@]}" "--" \
      -proc:none -classpath "$CP" "$WORK/Hello.java" >> "$3"
  done
}
emit 0 1 "$WORK/off_1.bin"; emit 0 "$K" "$WORK/off_K.bin"
emit 1 1 "$WORK/on_1.bin";  emit 1 "$K" "$WORK/on_K.bin"

# Worker process exit zero does not imply individual compile requests succeeded.
# Check every response in each stream before accepting timing results.
python3 - "$HERE/pgo" "$ELIDE" "$WORK" "$K" <<'PYCHECK'
import os, pathlib, subprocess, sys
sys.path.insert(0, sys.argv[1])
from gen_workrequest import check_responses
work = pathlib.Path(sys.argv[3])
for mode in ("off", "on"):
    for count in ("1", "K"):
        result = subprocess.run([sys.argv[2], "--safe-close", "javac", "--persistent_worker"],
            input=(work / f"{mode}_{count}.bin").read_bytes(), capture_output=True,
            env=dict(os.environ, ELIDE_BAZEL="1"), check=True)
        check_responses(result.stdout, 1 if count == "1" else int(sys.argv[4]))
PYCHECK
export ELIDE_BAZEL=1

echo "elide: $("$ELIDE" --version 2>/dev/null | head -1)  |  classpath: $NJARS jars  |  RUNS=$RUNS K=$K"
hyperfine --warmup "$WARMUP" --runs "$RUNS" --export-json "$RESULT_JSON" \
  -n "one-shot (cold)"          "$ELIDE javac --jar $WORK/out/os.jar -- -proc:none -classpath $CP $WORK/Hello.java" \
  -n "worker cache OFF (1-req)" "$ELIDE --safe-close javac --persistent_worker < $WORK/off_1.bin" \
  -n "worker cache OFF (${K}-req)" "$ELIDE --safe-close javac --persistent_worker < $WORK/off_K.bin" \
  -n "worker cache ON  (1-req)" "$ELIDE --safe-close javac --persistent_worker < $WORK/on_1.bin" \
  -n "worker cache ON  (${K}-req)" "$ELIDE --safe-close javac --persistent_worker < $WORK/on_K.bin"

echo
echo "=== warm per-compile (marginal) — the --classpath-cache gain ==="
python3 - "$RESULT_JSON" "$K" <<'PY'
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
