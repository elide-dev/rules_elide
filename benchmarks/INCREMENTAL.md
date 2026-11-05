# Incremental edit matrix

The single-library benchmark measures compiler latency after a comment edit.
This suite measures how edits propagate across a dependency graph, including
changes that affect bytecode without changing source-level method signatures.

```mermaid
graph LR
    Core --> Facade
    Spare[Unused declared dependency] --> Facade
    Facade --> Client0
    Facade --> Client1
    Facade --> Client2
    Client0 --> App
    Client1 --> App
    Client2 --> App
```

Arrows point from dependency to consumer. Core has 20 source files by default;
Facade, Spare, each client, and App have one. Java and Kotlin use equivalent
separate graphs. Every build requests **all runtime jars**, so ABI modes cannot
appear faster merely by building dependency headers and omitting runtime code.

| Edit | What changes | API boundary |
| --- | --- | --- |
| `clean` | Untimed `bazel clean`, followed by a timed full rebuild | All runtime targets are requested; dependencies remain downloaded |
| `no_op` | Nothing | Control for Bazel/logging overhead; must execute no full compilers |
| `comment` | One Core file's comment | No ABI or runtime behavior change |
| `body` | One Core method body | Behavior changes, signature stays fixed |
| `private_member` | Private method added to Core | No public Core API change |
| `internal_module_api` | Public method added to Core | Internal dependency API changes; Facade's exposed methods stay fixed |
| `public_module_api` | Public method added to Facade | API seen by all clients changes |
| `multi_file_body` | Three Core files' bodies | Several dirty files within one target, no public API change |
| `multi_module_body` | Core and Facade bodies | Two dirty targets, no public API change |
| `multi_module_api` | Public methods added to Core and Facade | Two targets' APIs change |
| `unused_dependency_api` | Public method added to Spare | Tests pruning of a declared but unused dependency |
| `inline_or_constant` | Java constant or Kotlin inline body in Core | Signatures stay fixed, but callers must observe changed compile-time code |

API edits are additive, keeping every graph compilable. This does not model a
breaking signature migration that also needs consumer source changes. The
internal/public module distinction is defined by the Facade boundary; it does
not imply Java JPMS enforcement or that Bazel will automatically hide transitive
classpath changes. The action logs reveal how far changes actually propagate.

[Recorded results](INCREMENTAL_RESULTS.md) include all 99 cases and the slower paths,
with structured sample data retained in the repository. A subsequent
[combined ABI comparison](FUSED_ABI_RESULTS.md) covers all 121 cases with the new
Kotlin modes.

## Modes

- `vanilla`: stock `java_library` / `kt_jvm_library` with their default ABI behavior.
- `vanilla_abi`: stock Kotlin with its opt-in `--define=experimental_use_abi_jars=1`.
  This compares optimized Elide against a stock ABI-enabled baseline as well as
  stock defaults. Java already uses headers by default, so this mode is Kotlin-only.
- `elide`: native Elide rules, default worker mode and flags.
- `elide_abi`: Elide with language-specific `abi_compile_avoidance=true`.
- `elide_pruned`: ABI mode plus dependency reporting and unused-input pruning.
- `elide_fused`: language-specific ABI mode with `abi_from_compile=true`; emits full and
  header jars in one compiler action. Consumers wait for that action to finish.
- `elide_fused_pruned`: Java/Kotlin combined emission plus unused-input pruning.
- `elide_hybrid`: experimental, explicit selection only. Uses per-target
  `abi_mode="separate"` for Core and `abi_mode="combined"` for all consumers and
  Spare. Global ABI flags stay at defaults. Compare against uniform separate
  and combined emission to evaluate overlap between Core code generation and
  downstream compilation. It is excluded from the default matrix.
- `elide_incremental`: Kotlin only, ABI mode plus experimental per-target
  incremental compilation. Pruning is deliberately off because IC is an opaque
  compile path. Compiler-action counts cannot show how many files IC recompiles
  inside one action.

These are native Elide rules, not the rules_kotlin KotlinBuilder adapter.
Mixed-language modules, processors, resource edits, dependency upgrades,
parallel fan-out scaling, and remote execution need separate experiments.

## Run and interpret

```sh
python3 benchmarks/incremental_matrix.py --sources 20 --fanout 3 --rounds 3
# Focused run; --distdir may be repeated to reuse downloaded distributions:
python3 benchmarks/incremental_matrix.py --languages kotlin \
  --modes vanilla elide_abi elide_pruned --scenarios body public_module_api
```

The **Incremental benchmarks** workflow runs the complete matrix on demand and
uploads `incremental-benchmark-results`. Results contain a Markdown table,
structured JSON with every measured sample, full compiler targets, ABI/header
targets, mnemonic counts, and raw Bazel execution logs. Failed builds fail the
benchmark; an edit that compiles no runtime target also fails validation.

The suite uses a temporary workspace/output base and shuts it down on exit.
Shared action caches and remote execution are disabled. Before **each** edit it
restores and rebuilds the pristine graph outside timing. It discards warm-up
rounds and reports means, medians, and sample standard deviations. Times include
Bazel invocation, analysis, and execution-log overhead; use the no-op control to
understand the floor. Do not subtract noisy no-op samples to claim compiler-only
performance. Hosted runners and sequential mode ordering introduce noise; repeat
runs before treating small differences as regressions.

Outputs default to `benchmarks/results/incremental/` (ignored by Git).
Use a different `--output` directory to retain multiple runs. These measurements
show recompilation behavior, not a proof of ABI soundness; runtime-result and
cache-invalidation tests remain necessary.

The workflow's `language` input selects `both`, `java`, or `kotlin`. This allows
focused comparisons without rerunning the other language. Java now includes
combined-emission modes; a full default run contains 168 cases and 504 measured
samples. Earlier recorded reports retain their original mode counts.

## Critical-path and memory traces

Pass `--profiles` to retain a compressed Bazel trace for every measured/warm-up
build and summarize it in JSON and Markdown. The workflow exposes a matching
`profiles` boolean. Each mode now starts with a fresh Bazel server and worker
pool; dependency fetching, baseline builds, and warm-ups remain outside timing.
This prevents workers from another mode contaminating memory counters. Historical
reports without `isolated_mode_servers` used shared server lifetimes across modes.

The trace summary records critical-path action time, its elapsed span (including
gaps), maximum recorded worker memory, worker memory by mnemonic, and Bazel's
heap-plus-non-heap usage. Memory is in MiB, following Bazel's counter definitions.
These are sampled, complete bucket averages, **not process peak RSS**. Bazel
uses one-second buckets; a partial tail can substantially understate memory on
short builds. A series contributes a bucket only when a later positive bucket
proves sampling crossed its boundary. Otherwise memory remains unknown. Short builds can
miss transient peaks; worker counters exclude non-worker compiler processes, and
Bazel's memory counter excludes native process overhead. Missing counters are
`null`/`n/a`, never treated as a zero-memory win. The sum of separate per-mnemonic
maxima need not equal the observed total maximum.

Compare profiled runs against each other. The original unprofiled wall-clock
reports remain useful, but trace collection and server isolation are methodology
changes. Raw traces can be inspected in a Chrome trace viewer to locate worker,
classpath, and scheduling overhead before choosing another optimization.

Run the trace interpretation tests with:

```sh
python3 -m unittest discover -s benchmarks -p '*_test.py'
```

The report records whether tracked workspace changes were present. Local experiments
with uncommitted changes must not be attributed solely to the recorded HEAD commit.
Earlier comparisons used stock Kotlin defaults; the new `vanilla_abi` mode is needed
before claiming superiority over stock Kotlin's optional ABI configuration.

## Production Java sources

Use a local [Apache Commons Lang](https://github.com/apache/commons-lang) checkout
for a real library compilation workload:

```sh
python3 benchmarks/incremental_matrix.py --languages java \
  --commons-lang /path/to/commons-lang --modes vanilla elide_abi elide_fused \
  --rounds 5 --output /tmp/commons-lang-comparison
```

The harness snapshots `src/main/java` into its temporary workspace without
modifying the checkout. It records the source revision, checkout dirty status,
source count, and a digest of the exact source paths and contents. Maven configuration
and tests are not copied. Stock Bazel's extra Error Prone checks are disabled
for this fixture (`--javacopt=-XepDisableAllChecks`): the upstream sources compile
with javac but trigger those additional checks. Elide does not run Error Prone.
This comparison therefore does not measure static-analysis feature parity. Java 21 or newer must be on PATH for runtime assertions;
the runtime version is recorded separately from the Bazel compilation toolchain.
The `--sources` parameter applies only to generated fixtures and does not resize
Commons Lang.

This replaces the generated Core target with the whole production library;
Facade, clients, and App remain generated consumers. It represents a real Java
library behind a small consumer graph, not a real application's full build.
Supported scenarios are `clean`, `no_op`, `comment`, `body`, `private_member`,
`internal_module_api`, `public_module_api`, and `multi_file_body`. The body edit
changes `StringUtils.isEmpty` from a length comparison to `CharSequence.isEmpty`.
The multi-file edit also rewrites equivalent predicates in `CharUtils` and
`BooleanUtils`. API/private edits add a method. Unique comments distinguish
repeated body edits in the action cache without changing their behavior.
Unexpected source shapes fail the benchmark rather than silently timing a no-op.

Every measured build is followed by an untimed runtime assertion through the
consumer graph. ABI-enabled modes must compile only Core for implementation,
private-member, and multi-file body edits. This is a smoke check, not the upstream
Commons Lang test suite or a complete language-compatibility check.

The workflow's `workload=commons-lang` option checks out Apache Commons Lang at
`67cbf817b6af58fc168d26774186e889bb9efe50`, selects Java, and runs all six Java modes
and eight supported scenarios. `language` and `sources` affect only the
`generated` workload. The production checkout is isolated from the rules checkout.

## Java target alignment

Java comparisons explicitly target release 21: stock uses Bazel's
`--java_language_version=21`, while native Elide targets receive
`javac_opts=["--release", "21"]`. Commons Lang runtime verification also inspects
every emitted class and requires classfile major version 65. This catches target
drift even when the verification JVM supports newer bytecode. Reports record
`java_release=21`.

Earlier Java reports without `java_release` used Elide's compiler default (Java
25 with Elide 1.6.2) against stock Java 21. Their rebuild counts remain useful,
but timings are not a comparison of matched compilation targets and must be
rerun before attributing differences to the rules or choosing defaults. Kotlin's
stock and native compiler defaults both target JVM 1.8 in the recorded runs.

The `clean` scenario measures a rebuild after `bazel clean`; cleanup is outside
measurement. Dependency downloads and initial setup remain warm. It does not
measure a cold machine, empty repository cache, or first installation. Each sample
still builds every runtime target and runs the Commons Lang consumer assertions
when that workload is selected. For example:

```sh
python3 benchmarks/incremental_matrix.py --languages java \
  --commons-lang /path/to/commons-lang --scenarios clean body \
  --modes vanilla elide elide_fused --rounds 5
```

[Recorded Commons Lang results](COMMONS_LANG_RESULTS.md) retain all 42 cases from
the first hosted run with matched Java targets. Stock Java was faster in every
scenario by median; that run predates the compiler input reductions.
