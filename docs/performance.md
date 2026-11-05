# Compilation performance

Use the [real Java results](../benchmarks/COMMONS_LANG_CLEAN_RESULTS.md),
[production Kotlin results](../benchmarks/KOTLIN_BUILDER_RESULTS.md), and
[generated-graph results](../benchmarks/INCREMENTAL_RESULTS.md) to evaluate
optimizations for your dependency graph. The [target ledger](../benchmarks/PERFORMANCE_TARGETS.md)
tracks measured wins and remaining gaps against stock rules. Clean rebuilds favor
Elide in these real-source fixtures. Warm implementation edits still favor stock
Java; Kotlin benefits from ABI avoidance and incremental state, but public API
edits and incremental adapter memory remain gaps. No setting wins every case.
Keep clean rebuilds separate from warm edits and first-install/download costs.

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

## Per-target ABI strategy

Native Java/Kotlin libraries, binaries, and tests accept `abi_mode`. Its default,
`"inherit"`, preserves the language's build-wide settings. `"off"` selects the
normal full-compile plus ijar path, `"separate"` requests early source headers,
and `"combined"` requests full and header output from one compiler action.
Explicit choices enable or disable that strategy independently of global flags.
The existing eligibility checks still apply: for example, a Kotlin target with
resources falls back from combined emission to separate headers, and Java
annotation processing retains the full-compile ijar path.

```starlark
elide_java_library(
    name = "core",
    srcs = glob(["core/*.java"]),
    abi_mode = "separate",
)

elide_java_library(
    name = "service",
    srcs = glob(["service/*.java"]),
    deps = [":core"],
    abi_mode = "combined",
)
```

This allows downstream compilation to start after Core's header is ready while
avoiding a separate header pass for Service. It is a scheduling option, not a
claim that this combination wins on every graph. Compare both strategies on real
code; the experimental `elide_hybrid` benchmark mode uses this arrangement and
must be selected explicitly with `--modes`.

## Remaining rule-side work

1. **Mixed-strategy measurement.** Use per-target `abi_mode` to compare early
   headers at dependency roots with combined emission at consumers. Measure
   scheduling and memory costs before recommending a layout.
2. **Wider correctness coverage.** Extend combined emission to resources, mixed
   sources, compiler plugins, processors, and friends only after proving header
   completeness and downstream runtime behavior. Test cache hits and remote
   execution as well as local workers.
3. **Incremental worker costs.** Native IC uses a singleplex Java adapter to keep
   compiled classes and cache together across edits, then writes the complete jar
   in the same action. This avoids Elide 1.6.2's missing-class behavior when Bazel
   deletes declared outputs. The adapter adds JVM startup and memory costs;
   measure those against the removed jar-pack process before recommending IC.
   Worker restarts and changed arguments/non-source inputs discard the state.
   One-shot execution is cold. The [IC guards](../e2e/ic_correctness/README.md)
   distinguish the underlying compiler behavior from the Bazel integration.
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

## Java classpath cache eligibility

`--@rules_elide//config/javac:classpath_cache=true` opts persistent Java workers
into digest-keyed classpath reuse. Processor-free targets receive `-proc:none`,
which the compiler requires before reusing file managers. Explicit processing
options and declared plugins remain authoritative and can make a request
ineligible. This opt-in disables implicit discovery of processors found only on
the classpath; configure processors explicitly when needed. The default remains
off. Empty classpaths, one-shot compilation, and unsupported compiler options do
not benefit from this cache.

`benchmarks/javac_cache.sh` isolates repeated compilation against the distribution's
jars. It now supplies dependency digests, disables processing in both modes, and
checks individual worker responses before timing. Earlier versions omitted both
eligibility requirements; their cache comparisons and explanations of negligible
benefit were unsupported. Set `RESULT_JSON=/path/to/results.json` to retain raw
hyperfine samples. This diagnostic is not a stock Java comparison, and a trivial
source with many dependencies cannot establish a production application speedup.
The Commons Lang core benchmark has no external dependency classpath, so this
optimization does not address its warm compilation regression.
