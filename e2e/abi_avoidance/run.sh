#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Soundness harness for Karbine ABI compile-avoidance (`elide kotlinc --abi-only`),
# the capability behind rules issue #11 / //config/kotlinc:abi_compile_avoidance.
#
# The rule uses the `--abi-only` header jar as `JavaInfo.compile_jar`. That is
# only correct if the header's digest is a faithful function of the public ABI:
#
#   * a change that callers DON'T observe (a method body) must leave the header
#     byte-identical  -> Bazel prunes dependents (the win), and
#   * a change that callers DO observe (const value, inline body, signature)
#     must change the header                       -> dependents rebuild (sound).
#
# A false "stable" in the second class is a silent-miscompile: a dependent keeps
# stale `const`/`inline` bytes. This harness makes both directions explicit.
#
# It also pins the two implementation-critical `--abi-only` behaviors the rule
# wiring depends on: it accepts a `-d <jar>` output, and on mixed kt+java it
# emits both the Kotlin and Java ABI (so the header is complete for mixed
# targets).
#
# Usage:  ELIDE=/path/to/elide ./run.sh        (or: ./run.sh /path/to/elide)
# Exits non-zero if any assertion fails.
set -uo pipefail

ELIDE="${ELIDE:-${1:-elide}}"
command -v "$ELIDE" >/dev/null 2>&1 || { echo "elide not found (set ELIDE=...): $ELIDE" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/abi-avoid.XXXXXX")"; trap 'rm -rf "$WORK"' EXIT
rc=0
echo "elide: $("$ELIDE" --version 2>/dev/null | head -1)"

# abi_digest <srcfile> -> stable digest of the emitted ABI .class bytes.
# Compiles to a dir (class bytes are deterministic; jar wrappers carry mtimes).
abi_digest() {
  local src="$1" out; out="$(mktemp -d "$WORK/o.XXXXXX")"
  "$ELIDE" kotlinc --abi-only -- -d "$out" -cp . "$src" >/dev/null 2>&1 || { echo "COMPILE-FAIL"; return; }
  (cd "$out" && find . -name '*.class' | LC_ALL=C sort | xargs cat 2>/dev/null | sha256sum | cut -d' ' -f1)
}

# assert_abi <name> <orig-src> <edited-src> <same|diff> <why>
assert_abi() {
  local name="$1" orig="$2" edit="$3" want="$4" why="$5"
  local f="$WORK/$name.kt"
  printf '%s\n' "$orig" > "$f"; local a; a="$(abi_digest "$f")"
  printf '%s\n' "$edit" > "$f"; local b; b="$(abi_digest "$f")"
  local got; [ "$a" = "$b" ] && got="same" || got="diff"
  if [ "$got" = "$want" ]; then
    printf '  ok   %-22s abi %-4s (%s)\n' "$name" "$got" "$why"
  else
    printf '  FAIL %-22s abi %-4s, wanted %s (%s)\n' "$name" "$got" "$want" "$why" >&2
    rc=1
  fi
}

echo "=== prune-soundness: header digest tracks ABI, not bodies ==="
assert_abi body-edit \
  'package s
class C { fun f(x: Int): Int { return x + 1 } }' \
  'package s
class C { fun f(x: Int): Int { return x + 99 } }' \
  same "plain body — callers unaffected, must prune"

assert_abi const-edit \
  'package s
object C { const val V: Int = 1 }' \
  'package s
object C { const val V: Int = 2 }' \
  diff "const is inlined into callers — must rebuild"

assert_abi inline-edit \
  'package s
object C { inline fun f(x: Int): Int = x + 1 }' \
  'package s
object C { inline fun f(x: Int): Int = x + 99 }' \
  diff "inline body is inlined into callers — must rebuild"

assert_abi signature-edit \
  'package s
class C { fun f(x: Int): Int = x }' \
  'package s
class C { fun f(x: Long): Long = x }' \
  diff "signature change — must rebuild"

assert_abi default-arg-edit \
  'package s
class C { fun g(x: Int = 1): Int = x }' \
  'package s
class C { fun g(x: Int = 2): Int = x }' \
  same "default value lives in the \$default bridge, not callers — body-level"

echo "=== implementation-critical --abi-only behaviors the rule relies on ==="
# (1) jar output: the rule passes `-d <name>_abi.jar`.
printf 'package s\nclass J { fun f(): Int = 1 }\n' > "$WORK/J.kt"
"$ELIDE" kotlinc --abi-only -- -d "$WORK/J_abi.jar" -cp . "$WORK/J.kt" >/dev/null 2>&1
if [ -f "$WORK/J_abi.jar" ] && unzip -l "$WORK/J_abi.jar" 2>/dev/null | grep -q 's/J.class'; then
  echo "  ok   jar-output             -d <jar> produces a jar of ABI classes"
else
  echo "  FAIL jar-output             -d <jar> did not produce a class jar" >&2; rc=1
fi

# (2) mixed kt+java: --abi-only emits both the Kotlin and Java ABI, so the
# header is complete and the rule can use it for mixed targets too.
printf 'package s\nclass K { fun f(): Int = 1 }\n' > "$WORK/K.kt"
printf 'package s;\npublic final class L { public static int g() { return 2; } }\n' > "$WORK/L.java"
mkdir -p "$WORK/mx"
"$ELIDE" kotlinc --abi-only -- -d "$WORK/mx" -cp . "$WORK/K.kt" "$WORK/L.java" >/dev/null 2>&1
has_k=$([ -f "$WORK/mx/s/K.class" ] && echo 1 || echo 0)
has_l=$([ -f "$WORK/mx/s/L.class" ] && echo 1 || echo 0)
if [ "$has_k" = 1 ] && [ "$has_l" = 1 ]; then
  echo "  ok   mixed-kt-and-java     --abi-only emits both Kotlin and Java ABI"
else
  echo "  FAIL mixed-kt-and-java     expected K.class and L.class (K=$has_k L=$has_l)" >&2; rc=1
fi

echo
[ "$rc" -eq 0 ] && echo "ABI avoidance: all assertions passed." || echo "ABI avoidance: FAILURES above." >&2
exit "$rc"
