#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Incremental-compilation correctness harness for `elide kotlinc --incremental`.
#
# IC's dangerous failure mode is "fast but silently stale": reusing cache state
# across edits yields output that differs from a clean build. This harness makes
# that impossible to miss. It walks a sequence of full module snapshots and, at
# every step, asserts:
#
#   IC-reused output  ==(byte-identical)==  fresh-cache build of the same sources
#
# Both sides use the SAME code path (`--incremental`) and a pinned `-module-name`,
# so the only variable is whether the cache/output carries prior-edit state. Any
# byte difference is therefore an IC bug, not a benign codegen/metadata artifact.
# (kotlinc output is deterministic, and the IC path differs from a plain compile
# in module-file naming — hence fresh-cache-IC, not plain compile, is the oracle.)
#
# The snapshots exercise the cases that catch real IC bugs:
#   00 initial          baseline multi-file module with cross-file edges
#   01 body-only        non-ABI body change in a leaf (only that file dirties)
#   02 const change     const inlined into an *untouched* caller (inlining trap)
#   03 inline-fn change  inline body inlined into an *untouched* caller (trap)
#   04 signature change  ABI change + caller update (cross-file propagation)
#   05 add file          new source + new dependent edge
#   06 delete file       removed source — IC must drop the stale .class
#
# Usage:  ELIDE=/path/to/elide ./run.sh        (or: ./run.sh /path/to/elide)
# Exits non-zero if any step diverges from its clean-build oracle.

set -euo pipefail

ELIDE="${ELIDE:-${1:-elide}}"
command -v "$ELIDE" >/dev/null 2>&1 || { echo "elide binary not found: $ELIDE" >&2; exit 2; }

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ic-correctness.XXXXXX")"
trap 'rm -rf "$ROOT"' EXIT
WORK="$ROOT/src"        # persistent source tree (edited in place across steps)
ICOUT="$ROOT/ic-out"    # persistent IC output dir (under test)
CACHE="$ROOT/ic-cache"  # persistent IC cache dir (under test)
mkdir -p "$WORK" "$ICOUT" "$CACHE"

MODULE="ic"
PASS=0; FAIL=0

# --- module snapshots: each writes the COMPLETE flat source set into $1 -------
# Edits between consecutive states are reviewable as the diff of these functions.

mod_00() { local d="$1"
  cat > "$d/Constants.kt" <<'KT'
package ic
object Constants { const val VERSION = 1; const val NAME = "alpha" }
KT
  cat > "$d/MathOps.kt" <<'KT'
package ic
object MathOps {
  fun square(x: Int): Int = x * x
  inline fun twice(x: Int): Int = x + x
}
KT
  cat > "$d/Formatter.kt" <<'KT'
package ic
object Formatter {
  fun banner(): String = "v" + Constants.VERSION + " " + Constants.NAME
  fun calc(n: Int): Int = MathOps.square(n) + MathOps.twice(n)
}
KT
  cat > "$d/Greeting.kt" <<'KT'
package ic
class Greeting(val who: String) { fun text(): String = "hi " + who }
KT
  cat > "$d/App.kt" <<'KT'
package ic
object App {
  fun run(): String = Formatter.banner() + " / " + Formatter.calc(3) + " / " + Greeting("world").text()
}
KT
}

# 01: body-only change in MathOps.square (no ABI change → no dependent recompile).
mod_01() { mod_00 "$1"
  cat > "$1/MathOps.kt" <<'KT'
package ic
object MathOps {
  fun square(x: Int): Int { val r = x * x; return r }
  inline fun twice(x: Int): Int = x + x
}
KT
}

# 02: change a const that Formatter inlines. Formatter.kt is untouched, but its
# .class must change — IC must recompile the inlining caller. (inlining trap)
mod_02() { mod_01 "$1"
  cat > "$1/Constants.kt" <<'KT'
package ic
object Constants { const val VERSION = 2; const val NAME = "alpha" }
KT
}

# 03: change an inline-fun body that Formatter.calc inlines. Formatter untouched,
# its .class must change — IC must recompile the inlining caller. (inlining trap)
mod_03() { mod_02 "$1"
  cat > "$1/MathOps.kt" <<'KT'
package ic
object MathOps {
  fun square(x: Int): Int { val r = x * x; return r }
  inline fun twice(x: Int): Int = x * 2
}
KT
}

# 04: signature change on Greeting.text() + caller update in App (ABI propagation).
mod_04() { mod_03 "$1"
  cat > "$1/Greeting.kt" <<'KT'
package ic
class Greeting(val who: String) { fun text(prefix: String): String = prefix + who }
KT
  cat > "$1/App.kt" <<'KT'
package ic
object App {
  fun run(): String = Formatter.banner() + " / " + Formatter.calc(3) + " / " + Greeting("world").text("hi ")
}
KT
}

# 05: add a new file + a new dependent edge from App.
mod_05() { mod_04 "$1"
  cat > "$1/Extra.kt" <<'KT'
package ic
class Extra { fun ping(): String = "pong" }
KT
  cat > "$1/App.kt" <<'KT'
package ic
object App {
  fun run(): String = Formatter.banner() + " / " + Formatter.calc(3) + " / " +
    Greeting("world").text("hi ") + " / " + Extra().ping()
}
KT
}

# 06: delete Extra.kt + drop the edge. IC must remove the stale Extra.class.
mod_06() { mod_04 "$1"; }  # identical to state 04 (Extra gone, App reverted)

STATES=(mod_00 mod_01 mod_02 mod_03 mod_04 mod_05 mod_06)
DESC=( \
  "00 initial baseline" \
  "01 body-only change (no ABI)" \
  "02 const change inlined into untouched caller" \
  "03 inline-fn change inlined into untouched caller" \
  "04 signature change + caller update" \
  "05 add file + new edge" \
  "06 delete file (stale .class must be removed)" )

# Copy only changed/new files and delete removed ones, preserving mtimes of
# untouched files so the IC dirty-set reflects a real incremental edit.
sync_sources() {
  local desired="$1" work="$2" f bn
  for f in "$work"/*.kt; do [ -e "$f" ] || continue
    bn="$(basename "$f")"; [ -e "$desired/$bn" ] || rm -f "$f"
  done
  for f in "$desired"/*.kt; do
    bn="$(basename "$f")"
    cmp -s "$f" "$work/$bn" 2>/dev/null || cp "$f" "$work/$bn"
  done
}

compile() { # $1=cache-dir $2=out-dir ; compiles $WORK/*.kt
  # Run from $ROOT (an ancestor of $WORK/$1/$2) so the sources sit *under* the
  # CWD. This sidesteps WHIPLASH#1113 — one-shot `kotlinc --incremental` reuse
  # spins in a runaway loop when the source file is outside the CWD subtree.
  # The bug itself is guarded separately by wl1113_regression.sh.
  ( cd "$ROOT" && "$ELIDE" kotlinc --incremental --incremental-cache-dir "$1" \
      -- -module-name "$MODULE" -d "$2" "$WORK"/*.kt )
}

echo "IC correctness harness  (elide: $("$ELIDE" --version 2>/dev/null | head -1))"
echo "================================================================"

for i in "${!STATES[@]}"; do
  desired="$ROOT/state.$i"; rm -rf "$desired"; mkdir -p "$desired"
  "${STATES[$i]}" "$desired"
  sync_sources "$desired" "$WORK"

  # under test: incremental compile reusing persistent cache + output dir
  if ! compile "$CACHE" "$ICOUT" >"$ROOT/ic.log" 2>&1; then
    echo "✗ ${DESC[$i]}"; echo "  IC compile FAILED:"; sed 's/^/    /' "$ROOT/ic.log"
    FAIL=$((FAIL+1)); continue
  fi

  # oracle: fresh-cache compile of the identical sources, throwaway dirs
  oc="$ROOT/oracle.cache.$i"; oo="$ROOT/oracle.out.$i"; mkdir -p "$oc" "$oo"
  if ! compile "$oc" "$oo" >"$ROOT/oracle.log" 2>&1; then
    echo "✗ ${DESC[$i]}"; echo "  oracle compile FAILED (bad fixture?):"; sed 's/^/    /' "$ROOT/oracle.log"
    FAIL=$((FAIL+1)); continue
  fi

  if diff -rq "$ICOUT" "$oo" >"$ROOT/diff.txt" 2>&1; then
    echo "✓ ${DESC[$i]}"
    PASS=$((PASS+1))
  else
    echo "✗ ${DESC[$i]}  — IC output diverged from clean build:"
    sed 's/^/    /' "$ROOT/diff.txt"
    # show a semantic hint for the first differing class
    first="$(grep -m1 '^Files ' "$ROOT/diff.txt" | sed -E 's/^Files (.*) and .* differ/\1/')"
    if [ -n "${first:-}" ] && command -v javap >/dev/null 2>&1; then
      rel="${first#$ICOUT/}"
      echo "    --- javap diff for $rel (IC vs clean) ---"
      diff <(javap -p -c "$ICOUT/$rel" 2>/dev/null) <(javap -p -c "$oo/$rel" 2>/dev/null) \
        | sed 's/^/    /' | head -30 || true
    fi
    FAIL=$((FAIL+1))
  fi
  rm -rf "$oc" "$oo"
done

echo "================================================================"
echo "result: $PASS passed, $FAIL failed (of ${#STATES[@]} steps)"
[ "$FAIL" -eq 0 ]
