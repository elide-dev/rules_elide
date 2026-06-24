# SPDX-License-Identifier: Apache-2.0
"""CodSpeed walltime benchmarks for the Elide compilers, vs a no-Elide baseline.

Times pure-compiler workloads over a generated N-file fixture, comparing the
Elide toolchain against the stock compilers on the same sources:

  * test_kotlinc_full[elide]    vs [vanilla]   — `elide kotlinc` vs stock kotlinc 2.4.0
  * test_javac_full[elide]      vs [vanilla]   — `elide javac`   vs stock javac
  * test_kotlinc_abi_only        — Elide-only (`--abi-only`; no stock equivalent)

The gain is the gap between the `elide` and `vanilla` times. CodSpeed runs each
many times on a dedicated, exclusive runner (the `walltime` job in
`.github/workflows/benchmarks.yml`).

Tool resolution (CI sets these; locally they fall back to PATH):
  ELIDE   — the Elide binary (CI: downloaded release)
  JAVAC   — stock javac   (CI: actions/setup-java)
  KOTLINC — stock kotlinc (CI: npm `kotlin-compiler@2.4.0` via bun)
A benchmark skips cleanly when its tool is absent.

    ELIDE=/abs/elide JAVAC=javac KOTLINC=/abs/kotlinc pytest benchmarks/codspeed [--codspeed]
"""

import itertools
import os
import shutil
import subprocess
from pathlib import Path

import pytest

ELIDE = os.environ.get("ELIDE", "elide")
JAVAC = os.environ.get("JAVAC", "javac")
KOTLINC = os.environ.get("KOTLINC", "kotlinc")

# Files per language in the fixture (matches the shell benchmarks' default of 50).
N_FILES = int(os.environ.get("CODSPEED_BENCH_FILES", "50"))

# Fresh output path per timed compile — a reused `-d` would let an incremental
# short-circuit hide real compile work.
_nonce = itertools.count()


def _tool_ok(tool: str) -> bool:
    return shutil.which(tool) is not None or (Path(tool).is_file() and os.access(tool, os.X_OK))


def _run(args: list[str]) -> None:
    # Capture bytes, decode only on failure: per-run decoding would add Python
    # overhead to the walltime signal we attribute to the compiler.
    proc = subprocess.run(args, capture_output=True)
    if proc.returncode != 0:
        err = proc.stderr.decode("utf-8", "replace")
        out = proc.stdout.decode("utf-8", "replace")
        raise AssertionError(f"{args[0]} exited {proc.returncode}: {' '.join(args)}\n{err}\n{out}")


@pytest.fixture(scope="session")
def workload(tmp_path_factory) -> dict:
    """Generates N self-contained Kotlin + Java sources; returns paths + outdir."""
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


@pytest.mark.parametrize("toolchain", ["elide", "vanilla"])
def test_kotlinc_full(benchmark, workload, toolchain):
    """Full Kotlin compile of N files: Elide vs stock kotlinc 2.4.0."""
    if toolchain == "elide":
        if not _tool_ok(ELIDE):
            pytest.skip(f"elide not found (set ELIDE=...): {ELIDE}")
        argv = lambda out: [ELIDE, "kotlinc", "--", "-d", out, *workload["kt"]]
    else:
        if not _tool_ok(KOTLINC):
            pytest.skip(f"stock kotlinc not found (set KOTLINC=...): {KOTLINC}")
        argv = lambda out: [KOTLINC, "-d", out, *workload["kt"]]

    def compile_once():
        _run(argv(str(workload["out"] / f"ktfull_{toolchain}{next(_nonce)}")))

    benchmark(compile_once)


def test_kotlinc_abi_only(benchmark, workload):
    """Karbine header-only (`--abi-only`) Kotlin compile — Elide-only."""
    if not _tool_ok(ELIDE):
        pytest.skip(f"elide not found (set ELIDE=...): {ELIDE}")

    def compile_once():
        out = workload["out"] / f"ktabi{next(_nonce)}"
        _run([ELIDE, "kotlinc", "--abi-only", "--", "-d", str(out), *workload["kt"]])

    benchmark(compile_once)


@pytest.mark.parametrize("toolchain", ["elide", "vanilla"])
def test_javac_full(benchmark, workload, toolchain):
    """Full Java compile of N files: Elide vs stock javac."""
    if toolchain == "elide":
        if not _tool_ok(ELIDE):
            pytest.skip(f"elide not found (set ELIDE=...): {ELIDE}")

        def compile_once():
            jar = workload["out"] / f"javac_elide{next(_nonce)}.jar"
            _run([ELIDE, "javac", "--jar", str(jar), "--", *workload["java"]])
    else:
        if not _tool_ok(JAVAC):
            pytest.skip(f"stock javac not found (set JAVAC=...): {JAVAC}")

        def compile_once():
            out = workload["out"] / f"javac_vanilla{next(_nonce)}"
            out.mkdir()  # javac (unlike elide) requires the -d directory to exist
            _run([JAVAC, "-d", str(out), *workload["java"]])

    benchmark(compile_once)
