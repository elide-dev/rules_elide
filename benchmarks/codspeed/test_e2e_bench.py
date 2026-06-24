# SPDX-License-Identifier: Apache-2.0
"""CodSpeed walltime benchmarks for an end-to-end Bazel build of e2e/integration.

Times `bazel build` of the `e2e/integration` consumer workspace through the Elide
toolchain, in two regimes:

  * cold        — full recompile (`bazel clean` between rounds)
  * incremental — rebuild after a 1-file edit (the dev inner loop)

Caches that would mask compile work are disabled on the build: no remote
cache/execution and no local disk action cache. The *repository* cache is kept,
so the pinned Elide download (DEFAULT_VERSION, via the workspace's own
`elide.install()`) is reused across rounds rather than re-fetched.

`benchmark.pedantic(setup=, teardown=)` runs setup/teardown UNTIMED between
rounds, so `clean`/edit/restore never land in a measured round. A warm-up build
runs first (also untimed) so the one-time Elide + maven download and first
analysis are excluded.

Local smoke:  pytest benchmarks/codspeed/test_e2e_bench.py
Measured:     under CodSpeedHQ/action (walltime); see .github/workflows/benchmarks.yml
"""

import itertools
import os
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
E2E = REPO_ROOT / "e2e" / "integration"
EDIT_SRC = E2E / "sample" / "Greeter.kt"

# Whole workspace except the upstream-blocked native_app (mirrors the CI
# integration job). The cache flags force honest compile work:
#   --disk_cache=             no local disk action cache
#   --remote_cache=           no remote cache
#   --remote_executor=        no remote execution
#   --noremote_accept_cached  never serve action results from a remote cache
# (empty values also override anything set in the workspace .bazelrc). The
# repository cache is intentionally left enabled.
_BUILD_ARGS = [
    "build",
    "--disk_cache=",
    "--remote_cache=",
    "--remote_executor=",
    "--noremote_accept_cached",
    "--noremote_upload_local_results",
    "--",
    "//...",
    "-//:native_app",
]

_nonce = itertools.count(1)


def _bazel_bin():
    for cand in (os.environ.get("BAZELISK"), "bazelisk", "bazel"):
        if cand and shutil.which(cand):
            return cand
    return None


def _run(bazel, *args):
    proc = subprocess.run([bazel, *args], cwd=str(E2E), capture_output=True, text=True)
    if proc.returncode != 0:
        # A failed build must fail the benchmark, not report a misleadingly fast time.
        raise AssertionError(
            f"bazel {' '.join(args)} (exit {proc.returncode})\n{proc.stderr[-4000:]}"
        )


@pytest.fixture(scope="session")
def bazel():
    b = _bazel_bin()
    if b is None:
        pytest.skip("bazelisk/bazel not found (set BAZELISK=...)")
    if not (E2E / "MODULE.bazel").is_file():
        pytest.skip(f"e2e/integration workspace not found at {E2E}")
    # Warm up (untimed): fetch Elide + maven, prime analysis.
    _run(b, *_BUILD_ARGS)
    yield b
    _run(b, "clean")  # leave no build outputs behind


def test_integration_cold(benchmark, bazel):
    """Full recompile each round: `bazel clean` (untimed) then build (timed)."""
    benchmark.pedantic(
        lambda: _run(bazel, *_BUILD_ARGS),
        setup=lambda: _run(bazel, "clean"),
        rounds=3,
        iterations=1,
    )


def test_integration_incremental(benchmark, bazel):
    """Rebuild after a 1-file edit: edit a source (untimed), build (timed), restore."""
    original = EDIT_SRC.read_text()

    def edit():
        # A unique trailing comment guarantees a content change (hence a recompile
        # of the dirtied target + dependents) every round, even if teardown is skipped.
        EDIT_SRC.write_text(f"{original}\n// codspeed bench edit {next(_nonce)}\n")

    def restore():
        EDIT_SRC.write_text(original)

    try:
        benchmark.pedantic(
            lambda: _run(bazel, *_BUILD_ARGS),
            setup=edit,
            teardown=restore,
            rounds=3,
            iterations=1,
        )
    finally:
        EDIT_SRC.write_text(original)
