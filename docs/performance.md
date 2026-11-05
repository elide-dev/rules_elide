# Compilation performance

Use the [incremental results](../benchmarks/INCREMENTAL_RESULTS.md) to select
optimizations for your dependency graph. The [target ledger](../benchmarks/PERFORMANCE_TARGETS.md)
tracks measured wins and remaining gaps against stock rules. The measured small graph favors Kotlin
ABI avoidance for implementation edits; pruning limits propagation through unused
transitive dependencies. Neither setting guarantees faster builds for every edit.

## Combined Java ABI emission

With Elide 1.6.2, compare the default Java rules against separate and combined
headers on your workload:

```sh
bazel build //... \
  --@rules_elide//config/javac:abi_compile_avoidance=true \
  --@rules_elide//config/javac:abi_from_compile=true
```

The full `ElideJavac` action writes both jars using `--emit-abi`, eliminating the
separate `ElideJavacAbi` action. Runtime jars retain implementations and resources;
compile consumers use the header. Processor/plugin options and `resource_jars`
retain the existing ijar fallback. Ordinary packaged resources are supported;
resource-only edits do not recompile the library or its consumers.

This is opt-in and requires Java ABI avoidance. Consumers wait for full
compilation, so saving an action can trade away useful graph parallelism.
Use the Java `elide_fused` and `elide_fused_pruned` benchmark modes to compare.
The [hosted Java results](../benchmarks/JAVA_FUSED_RESULTS.md) retain wins, regressions,
and timing outliers.

## Combined Kotlin ABI emission

With Elide 1.6.2, try:

```sh
bazel build //... \
  --@rules_elide//config/kotlinc:abi_compile_avoidance=true \
  --@rules_elide//config/kotlinc:abi_from_compile=true
```

The second setting emits full and header jars in one `ElideKotlinc` action instead
of scheduling another `ElideKotlincAbi` compiler pass. Both files are declared
outputs; downstream compile actions consume the header and runtime actions consume
the full jar. Body edits can still leave the header byte-identical.

This saves duplicated compiler work and a separate worker pool, but removes early
header availability: consumers must wait for full code generation. It is opt-in
and currently applies only to pure Kotlin targets without resources, plugins,
exported processors, friends, or incremental compilation. Other configurations
retain the separate header action. Without ABI avoidance the setting has no effect.

Compare `elide_abi` against `elide_fused`, and `elide_pruned` against
`elide_fused_pruned`, using the [matrix runner](../benchmarks/INCREMENTAL.md).
The [hosted comparison](../benchmarks/FUSED_ABI_RESULTS.md) records improvements
and remaining slower cases. Its action counts establish rebuild scope; timings require an otherwise idle
machine and repeated samples. Keep cold builds and warm edits as separate metrics.

## Remaining rule-side work

1. **Target-level selection.** Allow libraries to select separate headers or
   combined emission without changing the entire build. Large dependency roots
   may benefit from early headers while small leaves benefit from fewer passes.
2. **Wider correctness coverage.** Extend combined emission to resources, mixed
   sources, compiler plugins, processors, and friends only after proving header
   completeness and downstream runtime behavior. Test cache hits and remote
   execution as well as local workers.
3. **Incremental packaging.** Measure the cost of the classes-directory packing
   action before pursuing direct jar output or combined packaging. The current
   per-target IC path was slower on the 20-source benchmark; larger targets and
   correctness after deleted/renamed sources need dedicated measurements.
4. **Worker and classpath overhead.** Profile worker counts, memory, classpath
   hashing, and analysis cost on large graphs. Java header compilation currently
   does not use the full compiler's opt-in classpath cache; verify upstream support
   and cache invalidation before extending it.
5. **Benchmark coverage.** Add larger targets, deeper graphs, cold/remote builds,
   resource edits, deleted/renamed sources, and breaking API migrations. Record
   critical-path and memory data alongside wall time and action counts.

Do not narrow transitive compile classpaths merely to suppress invalidation:
exposed signatures, inline code, processors, and Kotlin metadata may need those
inputs. Dependency pruning must remain conservative when reads are opaque.
