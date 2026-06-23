# SPDX-License-Identifier: Apache-2.0
"""CodSpeed walltime benchmarks for the Elide compilers.

These mirror the pure-compiler workloads of the in-repo shell benchmarks
(`compile_modes.sh`, `javac_cache.sh`) but expressed as pytest-codspeed
benchmarks so CodSpeed can track wall-clock per PR. Each benchmark times a real
`elide` subprocess over a generated N-file fixture; CodSpeed runs it many times
on a dedicated, exclusive runner (the `walltime` job in
`.github/workflows/benchmarks.yml`).

Local smoke run (executes each workload once, no measurement):
    ELIDE=/abs/path/to/elide pytest benchmarks/codspeed

Measured run (under the CodSpeed runner, injected by CodSpeedHQ/action):
    ELIDE=/abs/path/to/elide pytest benchmarks/codspeed --codspeed
"""

import itertools
import os
import shutil
import subprocess
from pathlib import Path

import pytest

# Resolved elide binary. CI sets ELIDE to the downloaded release; locally it
# falls back to whatever `elide` is on PATH.
ELIDE = os.environ.get("ELIDE", "elide")

# Files per language in the fixture. Matches the shell benchmarks' default
# (`gen.sh 50`) so numbers are comparable across the two harnesses.
N_FILES = int(os.environ.get("CODSPEED_BENCH_FILES", "50"))

# Monotonic counter so every timed compile targets a fresh output path — a
# reused `-d` dir would let an incremental short-circuit hide real compile work.
_nonce = itertools.count()


@pytest.fixture(scope="session")
def workload(tmp_path_factory) -> dict:
    """Generates N self-contained Kotlin + Java sources; returns paths + outdir."""
    # Require an *executable* elide: a non-executable path would otherwise turn a
    # clean skip into a confusing subprocess failure deep in a benchmark.
    on_path = shutil.which(ELIDE) is not None
    runnable_file = Path(ELIDE).is_file() and os.access(ELIDE, os.X_OK)
    if not (on_path or runnable_file):
        pytest.skip(f"elide binary not found or not executable (set ELIDE=...): {ELIDE}")
    root = tmp_path_factory.mktemp("elide_bench")
    kt_dir = root / "kotlin" / "sample"
    java_dir = root / "java" / "sample"
    kt_dir.mkdir(parents=True)
    java_dir.mkdir(parents=True)
    for i in range(1, N_FILES + 1):
        (kt_dir / f"KotlinClass{i}.kt").write_text(
            f"package sample\n"
            f"object KotlinClass{i} {{\n"
            f"  fun value(): Int = {i}\n"
            f'  fun label(): String = "kotlin-{i}"\n'
            f"}}\n"
        )
        (java_dir / f"JavaClass{i}.java").write_text(
            f"package sample;\n"
            f"public final class JavaClass{i} {{\n"
            f"  private JavaClass{i}() {{}}\n"
            f"  public static int value() {{ return {i}; }}\n"
            f'  public static String label() {{ return "java-{i}"; }}\n'
            f"}}\n"
        )
    out = root / "out"
    out.mkdir()
    return {
        "kt": sorted(str(p) for p in kt_dir.glob("*.kt")),
        "java": sorted(str(p) for p in java_dir.glob("*.java")),
        "out": out,
    }


def _run(args: list[str]) -> None:
    # Capture as bytes and decode only on failure: decoding stdout/stderr on
    # every successful run would add Python-side overhead to the walltime signal
    # we are trying to attribute to the compiler.
    proc = subprocess.run(args, capture_output=True)
    if proc.returncode != 0:
        err = proc.stderr.decode("utf-8", "replace")
        out = proc.stdout.decode("utf-8", "replace")
        raise AssertionError(f"elide exited {proc.returncode}: {' '.join(args)}\n{err}\n{out}")


def test_kotlinc_full(benchmark, workload):
    """Full Kotlin compile of N files (cold process per compile)."""

    def compile_once():
        out = workload["out"] / f"ktfull{next(_nonce)}"
        _run([ELIDE, "kotlinc", "--", "-d", str(out), *workload["kt"]])

    benchmark(compile_once)


def test_kotlinc_abi_only(benchmark, workload):
    """Karbine header-only (`--abi-only`) Kotlin compile of N files."""

    def compile_once():
        out = workload["out"] / f"ktabi{next(_nonce)}"
        _run([ELIDE, "kotlinc", "--abi-only", "--", "-d", str(out), *workload["kt"]])

    benchmark(compile_once)


def test_javac_full(benchmark, workload):
    """Full Java compile of N files to a jar (cold process per compile)."""

    def compile_once():
        jar = workload["out"] / f"javac{next(_nonce)}.jar"
        _run([ELIDE, "javac", "--jar", str(jar), "--", *workload["java"]])

    benchmark(compile_once)
