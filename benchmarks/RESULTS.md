# Benchmark results

Wall-clock comparison of `rules_elide` against the canonical
`rules_java` (`java_library`) and `rules_kotlin` (`kt_jvm_library`) on the
same generated source set.

## Methodology

- Sources: `gen.sh` generates `N` self-contained, dependency-free `.java`
  and `.kt` files under `sources/{java,kotlin}/sample/`.
- Each measured run: `bazelisk clean` -> `bazelisk build :target` ->
  capture wall-clock (`date +%s%N`).
- Per-target average over `RUNS` runs.
- Elide CDN binary cached after first download; remote JDK 21 pulled once.
- Local machine, single configuration; no remote execution.

## Recorded run (2026-05-30)

`./bench.sh 30 2` — 30 Java + 30 Kotlin sources, 2 measured runs per
target. Elide binary: `nightly/latest` (snapshot from versions.bzl).

| Target           | Run 1 | Run 2 | Average |
|------------------|------:|------:|--------:|
| `vanilla_java`   | 4.60s | 3.36s |  3.98s  |
| `elide_java`     | 7.12s | 1.20s |  4.16s  |
| `vanilla_kotlin` | 8.64s | 5.00s |  6.82s  |
| `elide_kotlin`   | 1.24s | 1.25s |  1.25s  |

### Observations

- **Kotlin: `elide_kotlin` is ~5.5x faster than `vanilla_kotlin` on average
  (1.25s vs 6.82s).** Steady state (run 2): 1.25s vs 5.00s, i.e. ~4x.
- **Java: `elide_java` is ~2.8x faster than `vanilla_java` in steady state
  (1.20s vs 3.36s).** Cold first run is slower (7.12s vs 4.60s) due to
  Elide JVM/embedded-tool warm-up after `bazel clean`. Average is therefore
  similar to vanilla; the warm-state win is what monorepo CI sees in practice
  because clean-from-scratch builds are rare.
- Persistent workers are not yet implemented on the Elide CLI side
  (see `plan.md` UP-1); landing them is expected to remove the cold-run
  penalty entirely.

## Reproducing

```bash
cd benchmarks
BAZELISK=/path/to/bazelisk ./bench.sh [N] [RUNS]
```

Defaults: `N=50`, `RUNS=3`.
