# SPDX-License-Identifier: Apache-2.0
"""CodSpeed walltime benchmarks: Elide vs no-Elide on an end-to-end Bazel build.

Times `bazel build` of two sibling consumer workspaces that share identical
sources and target structure:

  * e2e/vanilla     — stock rules_java / rules_kotlin (the no-Elide BASELINE)
  * e2e/integration — the same project built through the Elide toolchain

Each is built in two regimes — cold (full recompile) and incremental (1-file
edit) — so CodSpeed reports four benchmarks:

    test_cold[vanilla]          test_cold[integration]
    test_incremental[vanilla]   test_incremental[integration]

The gain is the gap between the `vanilla` and `integration` times in each
regime; tracking both also catches the gain eroding over time. The two
workspaces are separate (own output bases, only their own toolchains
registered), so no Bazel state or toolchain bleeds between baseline and Elide.

The build disables action-result caches (no remote cache/exec, no disk cache) so
timings reflect real compile work; the repository cache is kept so downloads are
reused. `clean`/edit/restore run in untimed `pedantic` setup/teardown, and an
untimed warm-up build keeps one-time downloads + first analysis out of measured
rounds.

Local smoke:  pytest benchmarks/codspeed/test_e2e_bench.py
Measured:     under CodSpeedHQ/action (walltime); see .github/workflows/benchmarks.yml
"""

import itertools
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest

E2E = Path(__file__).resolve().parents[2] / "e2e"

# Workspaces under test. `vanilla` is the no-Elide baseline; `integration` is the
# same project through the Elide toolchain.
PROJECTS = {"vanilla": E2E / "vanilla", "integration": E2E / "integration"}

# A controlled generated fixture (200 .kt + 200 .java, identical in both
# workspaces). This isolates compiler/build behavior; it is not a real application
# and does not establish representative throughput or justify default changes.
TARGETS = ["//:gen_kt", "//:gen_java"]

# Force honest compile work: no remote cache/exec, no local disk action cache.
# Empty values also override anything in the workspace .bazelrc. Repository cache
# is left enabled so toolchain/dep downloads are reused across rounds.
_CACHE_FLAGS = [
    "--disk_cache=",
    "--remote_cache=",
    "--remote_executor=",
    "--noremote_accept_cached",
    "--noremote_upload_local_results",
]
_BUILD = ["build", *_CACHE_FLAGS, "--", *TARGETS]

_nonce = itertools.count(1)


def _bazel_bin():
    for cand in (os.environ.get("BAZELISK"), "bazelisk", "bazel"):
        if cand and shutil.which(cand):
            return cand
    return None


def _run(bazel, wd, *args):
    # A job-owned output base avoids runner-global startup rc overrides and
    # lets cleanup reclaim only this benchmark's generated state.
    output_base = wd.parent / ("bazel-" + wd.name)
    proc = subprocess.run([bazel, "--output_base=" + str(output_base), *args], cwd=str(wd), capture_output=True, text=True)
    if proc.returncode != 0:
        # A failed build must fail the benchmark, not report a misleadingly fast time.
        raise AssertionError(
            f"[{wd.name}] bazel {' '.join(args)} (exit {proc.returncode})\n{proc.stderr[-4000:]}"
        )


@pytest.fixture(scope="session")
def bazel():
    b = _bazel_bin()
    if b is None:
        pytest.skip("bazelisk/bazel not found (set BAZELISK=...)")
    return b


@pytest.fixture(scope="session", params=list(PROJECTS))
def project(request, bazel):
    source = PROJECTS[request.param]
    if not (source / "MODULE.bazel").is_file():
        pytest.skip(f"workspace not found: {source}")
    with tempfile.TemporaryDirectory(prefix="elide-codspeed-") as directory:
        wd = Path(directory) / source.name
        shutil.copytree(source, wd, ignore=shutil.ignore_patterns("bazel-*"))
        module = wd / "MODULE.bazel"
        contents = module.read_text()
        if request.param == "integration":
            # The fixture moved; resolve its rules checkout independently of cwd.
            contents = contents.replace('path = "../.."', 'path = ' + json.dumps(str(E2E.parent)))
            distribution = os.environ.get("ELIDE_DIST")
            if distribution:
                distribution = Path(distribution).resolve()
                if not (distribution / "bin/elide").is_file():
                    raise AssertionError(f"Invalid ELIDE_DIST: {distribution}")
                contents += "\nelide.use(local_path = " + json.dumps(str(distribution)) + ")\n"
            module.write_text(contents)
        try:
            _run(bazel, wd, *_BUILD)  # untimed fetch/analysis; cleanup covers setup failure
            yield bazel, wd
        finally:
            _run(bazel, wd, "clean", "--expunge")


def test_cold(benchmark, project):
    """Full recompile each round: `bazel clean` (untimed) then build (timed)."""
    bazel, wd = project
    benchmark.pedantic(
        lambda: _run(bazel, wd, *_BUILD),
        setup=lambda: _run(bazel, wd, "clean"),
        rounds=3,
        iterations=1,
    )


def test_incremental(benchmark, project):
    """Rebuild after a 1-file edit: edit a source (untimed), build (timed), restore."""
    bazel, wd = project
    src = wd / "gen" / "kotlin" / "Gen000.kt"  # one file in the gen_kt module
    original = src.read_text()

    def edit():
        # Unique trailing comment guarantees a content change (hence a recompile
        # of the dirtied target + dependents) every round, even if teardown is skipped.
        src.write_text(f"{original}\n// codspeed bench edit {next(_nonce)}\n")

    def restore():
        src.write_text(original)

    try:
        # The warm-worker module recompile is noisy (JVM GC/JIT), so use extra
        # warm-up rounds (untimed) to stabilize the worker before timing, plus
        # more timed rounds.
        benchmark.pedantic(
            lambda: _run(bazel, wd, *_BUILD),
            setup=edit,
            teardown=restore,
            rounds=7,
            warmup_rounds=3,
            iterations=1,
        )
    finally:
        src.write_text(original)
