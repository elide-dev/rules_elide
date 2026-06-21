#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Collect PGO profiles for the Elide kotlinc compile modes, over the 50-file,
# fully self-contained `benchmarks/sources/kotlin/sample` workload (package
# `sample`, kotlin-stdlib only — no classpath/maven needed). Each case drives a
# PGO-INSTRUMENTED elide binary in a distinct mode, in its own clean CWD, and
# collects the flushed `default.iprof` into `profiles/<case>.iprof`. Each profile
# is also copied to the WHIPLASH tree under a unique name for use as a
# `--pgo` input.
#
# `--safe-close` (top-level) is ALWAYS passed: empirically it is what flushes
# `default.iprof` on clean shutdown, in every mode (one-shot, abi, worker).
#
# Cases (each exercises a different hot path → a different profile):
#   oneshot    elide kotlinc -- -d <out> <srcs>             cold single compile
#   jvmabigen  full compile + jvm-abi-gen plugin (ABI jar side-output)
#   karbine    elide kotlinc --abi-only ...                 header-only (WHIPLASH#1111)
#   worker     N WorkRequests to elide kotlinc --persistent_worker (warm loop)
#   workercache PENDING — needs the in-worker classpath cache (WHIPLASH#1107)
#
# Usage:
#   ELIDE=/abs/path/to/instrumented/elide benchmarks/pgo/collect.sh [cases...]
#   (default cases: oneshot jvmabigen karbine worker)
#   WHIPLASH_PROFILES=<dir>  overrides the copy destination.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
ELIDE="${ELIDE:-${1:-elide}}"
[ "${1:-}" = "$ELIDE" ] && shift || true
command -v "$ELIDE" >/dev/null 2>&1 || { echo "elide not found: $ELIDE" >&2; exit 2; }

SAMPLE="$REPO/benchmarks/sources/kotlin/sample"
mapfile -t SRCS < <(ls "$SAMPLE"/*.kt)
[ "${#SRCS[@]}" -gt 0 ] || { echo "no sources under $SAMPLE" >&2; exit 2; }

PROFILES="$HERE/profiles"; mkdir -p "$PROFILES"
# Optional: set WHIPLASH_PROFILES=<dir> to also copy each profile there as
# kotlinc-<case>.iprof (e.g. a WHIPLASH checkout's tools/profiles). Left unset by
# default so the harness assumes nothing about the surrounding layout.
WHIPLASH_PROFILES="${WHIPLASH_PROFILES:-}"
WARM_ROUNDS="${WARM_ROUNDS:-3}" # worker requests, to exercise the warm loop
WORK="$(mktemp -d "${TMPDIR:-/tmp}/pgo-collect.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# jvm-abi-gen plugin jar, discovered under the elide distribution (same lookup as
# ElideCompile.findJvmAbiGenJar): <distRoot>/lib/resources/kotlin/<ver>/lib.
_abi_plugin() {
  local dist; dist="$(dirname "$(dirname "$(readlink -f "$ELIDE")")")"
  ls "$dist"/lib/resources/kotlin/*/lib/jvm-abi-gen.jar 2>/dev/null | head -1
}

# Collect the profile a case flushed into its CWD; fail loudly if none appeared.
_harvest() { # $1=case-name $2=cwd
  local case="$1" cwd="$2" prof
  prof="$(ls "$cwd"/*.iprof 2>/dev/null | head -1 || true)"
  if [ -z "$prof" ]; then echo "  ✗ $case: no .iprof flushed" >&2; return 1; fi
  cp "$prof" "$PROFILES/$case.iprof"
  local sz; sz="$(stat -c %s "$prof")"
  if [ -n "$WHIPLASH_PROFILES" ] && [ -d "$WHIPLASH_PROFILES" ]; then
    cp "$prof" "$WHIPLASH_PROFILES/kotlinc-$case.iprof"
    echo "  ✓ $case: $sz bytes → profiles/$case.iprof, $WHIPLASH_PROFILES/kotlinc-$case.iprof"
  else
    echo "  ✓ $case: $sz bytes → profiles/$case.iprof"
  fi
}

case_oneshot() {
  local cwd="$WORK/oneshot"; mkdir -p "$cwd/out"
  ( cd "$cwd" && "$ELIDE" --safe-close kotlinc -- -d out "${SRCS[@]}" >log 2>&1 )
  _harvest oneshot "$cwd"
}

case_jvmabigen() {
  local cwd="$WORK/jvmabigen"; mkdir -p "$cwd/out" "$cwd/abi"
  local plugin; plugin="$(_abi_plugin)"
  [ -n "$plugin" ] || { echo "  ✗ jvmabigen: jvm-abi-gen.jar not found under the dist" >&2; return 1; }
  ( cd "$cwd" && "$ELIDE" --safe-close kotlinc -- -d out \
      "-Xplugin=$plugin" -P "plugin:org.jetbrains.kotlin.jvm.abi:outputDir=$cwd/abi" \
      "${SRCS[@]}" >log 2>&1 )
  _harvest jvmabigen "$cwd"
}

case_karbine() {
  local cwd="$WORK/karbine"; mkdir -p "$cwd/out"
  ( cd "$cwd" && "$ELIDE" --safe-close kotlinc --abi-only -- -d out "${SRCS[@]}" >log 2>&1 )
  _harvest karbine "$cwd"
}

case_worker() {
  local cwd="$WORK/worker"; mkdir -p "$cwd"
  local stream="$cwd/requests.bin"; : > "$stream"
  # WARM_ROUNDS module compiles (rotating output dirs) → exercise the warm
  # request loop (BazelWorker.run, classloader reuse) across several requests.
  local i
  for ((i = 1; i <= WARM_ROUNDS; i++)); do
    mkdir -p "$cwd/out$i"
    python3 "$HERE/gen_workrequest.py" "--" "-d" "$cwd/out$i" "${SRCS[@]}" >> "$stream"
  done
  ( cd "$cwd" && "$ELIDE" --safe-close kotlinc --persistent_worker < "$stream" >log 2>&1 )
  _harvest worker "$cwd"
}

case_workercache() {
  echo "  ⏭ workercache: pending the in-worker classpath cache (WHIPLASH#1107); skipping" >&2
}

CASES=("$@")
[ "${#CASES[@]}" -gt 0 ] || CASES=(oneshot jvmabigen karbine worker)

echo "PGO collect  (elide: $("$ELIDE" --version 2>/dev/null | head -1))"
echo "  workload: ${#SRCS[@]} files under $SAMPLE"
echo "  copy dest: ${WHIPLASH_PROFILES:-<none; set WHIPLASH_PROFILES to also copy>}"
echo "================================================================"
rc=0
for c in "${CASES[@]}"; do
  echo "• $c"
  "case_$c" || rc=1
done
echo "================================================================"
echo "done (profiles in $PROFILES; copies as kotlinc-<case>.iprof)"
exit $rc
