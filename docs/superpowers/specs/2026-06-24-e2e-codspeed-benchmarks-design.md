# e2e project CodSpeed benchmarks — design

**Date:** 2026-06-24
**Status:** approved (brainstorm), pending spec review

## Goal

Track the wall-clock time to build a real rules_elide consumer project end-to-end
through the Elide toolchain, reported to CodSpeed per PR alongside the existing
compiler micro-benchmarks. Catches regressions the micro-benchmarks can't —
toolchain registration, worker launch, analysis, multi-target builds — on an
actual `bazel build` of `e2e/integration`.

## Scope

- **Project:** `e2e/integration` only (real Elide toolchain; `bazel build -- //...
  -//:native_app`, mirroring the integration CI job). `e2e/kotlin_builder` and
  `e2e/smoke` are out of scope for this iteration.
- **Regimes:** both **cold** (full recompile) and **incremental** (1-file edit).
- **Reporting:** CodSpeed walltime, in the existing `walltime` job of
  `.github/workflows/benchmarks.yml`, on `linux-amd64-bench`, on PR + main push.

## Approach

Extend the existing `benchmarks/codspeed` pytest-codspeed harness with a new
module `test_e2e_bench.py`, run by the same `pytest benchmarks/codspeed
--codspeed` invocation. CodSpeed reports the micro + e2e benchmarks together.
(Rejected: a separate job — more plumbing, two walltime uploads; hyperfine —
CodSpeed can't ingest it.)

## Harness — `benchmarks/codspeed/test_e2e_bench.py`

Each benchmark times a `bazelisk build` of `e2e/integration` via
`benchmark.pedantic(target, setup=, teardown=, rounds=N)` — `setup`/`teardown`
run **untimed** between rounds (confirmed supported in pytest-codspeed 5.0.3).

- **Resolution:** `bazelisk` from `$BAZELISK`/PATH; working dir `e2e/integration`.
  Skip cleanly (`pytest.skip`) if `bazelisk` or the workspace is absent — mirrors
  the existing harness skipping without `ELIDE`.
- **Warm-up:** one untimed `bazel build` before the timed rounds, so the one-time
  Elide download (~600 MB at repo-rule fetch) and first analysis are never inside
  a timed round.
- **`test_integration_cold`:** `setup = bazel clean`, `target = bazel build`.
  Each round recompiles from scratch.
- **`test_integration_incremental`:** `setup` edits a method body in one source
  (candidate `sample/Greeter.kt`; implementation picks a file whose edit forces a
  recompile and verifies it via the dirtied target), `target = bazel build`,
  `teardown` restores the file. Models the 1-file dev rebuild; leaves the
  workspace pristine.
- **Rounds:** small (≈3–5); Bazel builds take seconds. Tunable via pytest-codspeed
  markers (`max_rounds`/`max_time`) if needed.

## Build invocation & cache policy

`bazel build -- //... -//:native_app` with explicit flags so the measurement is
honest and self-contained (not dependent on the workspace `.bazelrc`):

- **Cold = `bazel clean` (NOT `--expunge`).** `clean` drops action outputs to
  force a full recompile while preserving the Elide repo download + repository
  cache (no 600 MB re-fetch per round) and the in-server analysis graph. So it is
  "cold *execution*, warm analysis" — measures compile work, which is the point.
- **No remote cache / no remote execution:** pass `--remote_cache=`
  `--remote_executor=` (empty) to override any ambient config, plus
  `--noremote_accept_cached`. The benchmark must never serve action results from
  a remote cache.
- **No local disk action cache:** pass `--disk_cache=` (empty) to disable it.
- **Repository cache stays enabled** (default / `--repository_cache` untouched) so
  the pinned Elide download is reused across rounds.
- Incremental rebuilds rely on the Bazel server's in-memory (skyframe)
  incrementality, which the cache flags above do not disable — so a 1-file edit
  still recompiles only the dirty target + dependents.

## Elide version

Already pinned: `e2e/integration/MODULE.bazel` uses `elide.install(channel=
"nightly")`, and the `install` tag's `version` defaults to `DEFAULT_VERSION`
(`elide/private/versions.bzl`). So the benchmark builds against the repo's pinned
Elide (currently `1.3.4+20260623`), advancing only when we bump `versions.bzl` —
i.e. "pinned to latest, as we go," with no nightly drift. No change required.

## Workflow

Extend the `walltime` job in `.github/workflows/benchmarks.yml`:

- Add Bazel availability (`bazel-contrib/setup-bazel`, pinned) so the same
  `pytest benchmarks/codspeed --codspeed` run can build `e2e/integration`.
- Unchanged: runner `linux-amd64-bench`, PR + main-push triggers, OIDC upload,
  the pinned-Elide download step (the micro-benchmarks still use `$ELIDE`).
- The e2e workspace resolves its own Elide via its `MODULE.bazel`; the `$ELIDE`
  binary the micro-benchmarks use is independent.

## Testing / validation

- Locally runnable: `ELIDE=… pytest benchmarks/codspeed` runs every benchmark
  once (pedantic with rounds executes the workload); with `bazelisk` + the e2e
  workspace present it exercises a real build. Skips cleanly when prerequisites
  are absent.
- The harness asserts the build exits 0 (a failed build must fail the benchmark,
  not silently report a fast time).
- CI: the `walltime` job runs it under CodSpeed and uploads.

## Out of scope / follow-ups

- `e2e/kotlin_builder` and `e2e/smoke` benchmarks.
- A `--config` in the e2e `.bazelrc` for the cache policy (kept in the harness for
  self-containment instead).
- Pinning rounds/time budgets precisely (start conservative, tune from observed
  CI variance).
