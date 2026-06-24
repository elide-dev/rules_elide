# CodSpeed walltime benchmarks

Continuous performance tracking for the Elide compilers, surfaced as per-PR
feedback by [CodSpeed](https://codspeed.io). These benchmarks mirror the
pure-compiler workloads of the shell benchmarks in the parent directory
(`compile_modes.sh`, `javac_cache.sh`) but are expressed as
[`pytest-codspeed`](https://github.com/CodSpeedHQ/pytest-codspeed) benchmarks so
CodSpeed can measure and compare them automatically.

## What runs

`test_compile_bench.py` times three real `elide` subprocess workloads over a
generated N-file fixture (default 50 files/language):

| Benchmark               | Command                                          |
| ----------------------- | ------------------------------------------------ |
| `test_kotlinc_full`     | `elide kotlinc -- -d <out> <N .kt>`              |
| `test_kotlinc_abi_only` | `elide kotlinc --abi-only -- -d <out> <N .kt>`   |
| `test_javac_full`       | `elide javac --jar <out.jar> -- <N .java>`       |

Each timed compile targets a fresh output path so no incremental short-circuit
hides real work. These isolate compiler wall-clock — not Bazel analysis or
caching — so the signal tracks Elide/rules_elide compile speed directly.

`test_e2e_bench.py` shows the **build-speed gain of Elide over a no-Elide
baseline** by building two sibling workspaces with identical sources/targets and
comparing them: `e2e/vanilla` (stock rules_java/rules_kotlin) vs `e2e/integration`
(the Elide toolchain). Each is built in two regimes, so CodSpeed reports four
benchmarks — the gain is the gap between `vanilla` and `integration` per regime:

| Benchmark                       | Regime                                          |
| ------------------------------- | ----------------------------------------------- |
| `test_cold[vanilla]`            | baseline, full recompile (`bazel clean`/round)  |
| `test_cold[integration]`        | Elide, full recompile                           |
| `test_incremental[vanilla]`     | baseline, rebuild after a 1-file edit           |
| `test_incremental[integration]` | Elide, rebuild after a 1-file edit              |

Both build the common target set (`//:lib //:app //:kt_lib //:kt_app
//:HelloTest`) with `--disk_cache= --remote_cache= --remote_executor=
--noremote_accept_cached` so timings reflect real compile work (no action-result
cache); the repository cache is kept so downloads are reused. `clean`/edit/restore
run in untimed `pedantic` setup/teardown, and a warm-up build (untimed) keeps
one-time downloads out of the measured rounds. Needs `bazelisk`/`bazel` on PATH
(or `$BAZELISK`); skips cleanly otherwise. The Elide build is pinned via
`e2e/integration`'s `elide.install()` → `DEFAULT_VERSION`, advancing as we bump
`versions.bzl`. The two workspaces stay isolated (separate output bases, only
their own toolchains registered).

## Running locally

```sh
# Smoke run — executes each workload once, no measurement:
ELIDE=/abs/path/to/elide pytest benchmarks/codspeed

# Walltime measurement (prints a results table; no upload outside CI):
ELIDE=/abs/path/to/elide pytest benchmarks/codspeed --codspeed
```

`CODSPEED_BENCH_FILES=<n>` overrides the fixture size.

## CI

The **Benchmarks** workflow (`.github/workflows/benchmarks.yml`) runs its
`walltime` job on every PR and on `main` pushes, on the self-hosted
**`linux-amd64-cipool`** pool. Walltime needs an exclusive, unshared machine to
be reliable; that pool provides it on x86_64. (CodSpeed's managed
`codspeed-macro` runners are ARM64-only, so we use the self-hosted AMD64 pool
instead.) Dependencies are provisioned with `uv` from `requirements.txt`. The
job downloads the Elide release pinned in `elide/private/versions.bzl`, so the
measurement is a function of repo changes and deliberate Elide bumps — not
nightly drift. (The same workflow's weekly `bench` job runs the heavier
whole-build hyperfine suite on a schedule.)

## One-time setup (manual, outside this repo)

1. Install the **CodSpeed GitHub App** on the `elide-dev` org and grant it the
   `rules_elide` repo (this is what posts the PR performance report). *(Done.)*
2. Authentication is via **OIDC** — the `walltime` job grants `id-token: write`,
   so no upload token/secret is needed.
3. Ensure the `linux-amd64-cipool` self-hosted runners have `curl`, `tar`, and
   `sha256sum` available. Python and the benchmark deps are provisioned by `uv`
   (installed by `astral-sh/setup-uv`), so no system Python is required.

## Extending

The shell benchmarks also cover warm-worker reuse and incremental rebuilds.
Those are harder to express faithfully as repeated-callable benchmarks (warm
state and real edits between runs), so they are intentionally left out of the
first cut. Add them as separate benchmark modules when the measurement model is
worked out.
