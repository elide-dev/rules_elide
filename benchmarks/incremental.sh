#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Incremental-compile benchmark for `elide kotlinc` (the Kotlin Build Tools API
# IC path). Measures a full compile vs an incremental rebuild after a real
# 1-file edit, on an inference-heavy module of mutually-independent files (so a
# correct IC recompiles ~one file). The process + page cache are pre-warmed so
# this is steady state, and every edit is VERIFIED real (the changed class's
# bytecode must differ) — a no-op edit gives a deceptively fast "win".
#
# Usage: ELIDE=/abs/path/to/elide benchmarks/incremental.sh [FILES] [FNS] [RUNS]
set -euo pipefail
ELIDE="${ELIDE:-elide}"; command -v "$ELIDE" >/dev/null 2>&1 || { echo "elide not found: $ELIDE" >&2; exit 2; }
FILES="${1:-12}"; FNS="${2:-60}"; RUNS="${3:-5}"
W="$(mktemp -d "${TMPDIR:-/tmp}/ic-bench.XXXXXX")"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/src" "$W/cache" "$W/d"

python3 - "$W" "$FILES" "$FNS" <<'PY'
import sys; W, F, N = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
for f in range(F):
    b = ["package m", "class H%d {" % f]
    for n in range(N):
        b.append(f"  fun a{f}_{n}(): Int {{ val m=(1..50).map {{ it to it.toString() }}"
                 f".groupBy {{ it.first%7 }}.mapValues {{ e -> e.value.sumOf {{ it.first }} }}; "
                 f"return m.values.fold(0) {{ a,b -> a+b }}+{n} }}")
    b.append("}"); open(f"{W}/src/H{f}.kt", "w").write("\n".join(b) + "\n")
PY

median() { printf '%s\n' "$@" | sort -n | awk '{a[NR]=$1} END{print (NR%2)?a[(NR+1)/2]:int((a[NR/2]+a[NR/2+1])/2)}'; }
full() { local s; s=$(date +%s%3N); "$ELIDE" kotlinc -- -d "$W/df$RANDOM" "$W"/src/*.kt >/dev/null 2>&1; echo $(($(date +%s%3N)-s)); }
ic()   { local s; s=$(date +%s%3N); "$ELIDE" kotlinc --incremental --incremental-cache-dir "$W/cache" -- -module-name m -d "$W/d" "$W"/src/*.kt >/dev/null 2>&1; echo $(($(date +%s%3N)-s)); }

"$ELIDE" kotlinc -- -d "$W/warm" "$W"/src/*.kt >/dev/null 2>&1   # warm process + page cache
echo "elide: $("$ELIDE" --version 2>/dev/null | head -1)  |  ${FILES} files x ${FNS} fns  |  RUNS=$RUNS"

full_t=(); for _ in $(seq "$RUNS"); do full_t+=("$(full)"); done
ic "$W" >/dev/null   # populate the IC cache

ic_t=()
for i in $(seq "$RUNS"); do
  f="$W/src/H$(( i % FILES )).kt"
  # toggle a real substring; verify the edited class actually recompiles
  if grep -q 'it.first%7' "$f"; then sed -i 's/it.first%7/it.first%8/g' "$f"; else sed -i 's/it.first%8/it.first%7/g' "$f"; fi
  cls="$W/d/m/H$(( i % FILES )).class"; before="$(md5sum "$cls" 2>/dev/null | cut -c1-8)"
  t="$(ic)"; after="$(md5sum "$cls" 2>/dev/null | cut -c1-8)"
  [ "$before" != "$after" ] && ic_t+=("$t") || echo "  WARN: edit $i did not change $cls (skipped)" >&2
done

fm="$(median "${full_t[@]}")"; im="$(median "${ic_t[@]}")"
echo "================================================================"
printf "  full compile (no IC):        %s ms (median of %d)\n" "$fm" "$RUNS"
printf "  IC, real 1-file edit:        %s ms (median of %d, verified)\n" "$im" "${#ic_t[@]}"
[ "$im" -gt 0 ] && printf "  → IC is %s.%sx faster on a 1-file edit\n" "$((fm/im))" "$(( (fm*10/im)%10 ))"
