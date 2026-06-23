# Benchmark results

Wall-clock comparison of `rules_elide` against the canonical
`rules_java` (`java_library`) and `rules_kotlin` (`kt_jvm_library`) on the
same generated source set, across three conditions:

- **baseline** — vanilla `rules_java` / `rules_kotlin`.
- **elide** — elide rules, persistent workers **off** (one-shot
  `elide <tool> -- <args>` per target, via `--@rules_elide//elide:use_workers=false`).
- **elide+worker** — elide rules, persistent workers **on** (default).

## Suite

`bench_suite.sh` drives [hyperfine](https://github.com/sharkdp/hyperfine) and
compares all three conditions, for Java and Kotlin, under two regimes:

- **cold** — `bazel clean` before each run (full from-scratch build). `clean`
  resets the worker pool, so even `elide+worker` spawns a fresh worker;
  isolates the elide-vs-baseline compiler win.
- **warm** — edit one source, rebuild without cleaning (incremental inner
  loop). `elide+worker` reuses its warm process.

```bash
cd benchmarks
BAZELISK=/path/to/bazelisk ./bench_suite.sh [N] [RUNS] [WARMUP]   # defaults: 50, 10, 3
```

Per-regime Markdown tables and JSON are written under `benchmarks/results/`.

## Recorded run

`./bench_suite.sh 50 8 3` — 50 Java + 50 Kotlin sources. Local machine, no
remote execution. Elide `1.3.0+20260613`. Means ± σ:

| Regime        | baseline      | elide        | elide+worker | elide vs baseline |
|---------------|--------------:|-------------:|-------------:|------------------:|
| java / cold   | 2.760 s       | 0.784 s      | 0.777 s      | **3.5x**          |
| java / warm   | 281.7 ms      | 227.4 ms     | 230.0 ms     | **1.24x**         |
| kotlin / cold | 5.212 s       | 0.955 s      | 1.039 s      | **5.5x**          |
| kotlin / warm | 875.4 ms      | 755.8 ms     | 780.7 ms     | **1.16x**         |

### Observations

- **elide is the win: ~3.5x (Java) and ~5.5x (Kotlin) faster than the vanilla
  baselines on cold builds**, and still faster warm. This is consistent and
  large.
- **Persistent workers are ~wall-clock-neutral for elide.** Across both
  regimes, `elide+worker` lands within noise of `elide` (and is marginally
  *slower* on Kotlin cold). The reason: elide is a GraalVM native image — a
  one-shot `elide javac` start+compile of a file is ~12 ms, so there is almost
  no per-invocation startup for a warm worker to amortize. Workers exist to
  amortize *JVM* startup (hundreds of ms for vanilla JavaBuilder/KotlinBuilder);
  elide simply does not pay that cost. Worker support is therefore about Bazel
  integration / protocol compatibility, not a wall-clock speedup here.
- **Singleplex caveat.** elide's worker is singleplex, so Bazel caps it at
  `--worker_max_instances` (default 4) while the one-shot path uses all cores.
  On wide parallel fan-out (many independent targets in one build) workers can
  be *slower* than one-shot — another reason the worker is not a perf lever for
  elide. The suite deliberately does not include a wide-fan-out regime.
- **Non-worker fallback.** The supported way to run elide without workers is
  `--@rules_elide//elide:use_workers=false` (the one-shot `--` form). Do *not*
  use `--worker_max_instances=0` / `--strategy=...=local`: that hits the broken
  upstream standalone path (WHIPLASH #994).

## Watching the worker run

```bash
cd benchmarks
./gen.sh 30
bazelisk clean
bazelisk build //:elide_java_lib --worker_verbose          # "Created new ... ElideJavac worker"
echo '// touch' >> sources/java/sample/JavaClass1.java
bazelisk build //:elide_java_lib --worker_verbose          # rebuilds via "1 worker", no new worker
```
