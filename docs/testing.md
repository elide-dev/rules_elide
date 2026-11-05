# Test coverage and limitations

The project uses three layers: Starlark analysis tests, KotlinBuilder unit and
protocol tests, and real Elide integration fixtures. A successful build alone
is not the same as checking the generated artifacts.

| Area | Assertions | Where |
| --- | --- | --- |
| Version/overlay selection | Known pins, matching overlay hashes, provider runtime inputs isolated from JVM inputs | `tests/versions_test.bzl`, `tests/toolchain_test.bzl` |
| Java/Kotlin rules | Providers, classpaths, ABI actions, resource and processor handling | `tests/java_rule_test.bzl`, `tests/kotlin_rule_test.bzl` |
| JVM tools | Flags, declared headers/processors, outputs, invalid prefixes/empty requests/missing processors | `tests/jvm_tools_test.bzl` |
| Compiler metadata | Reports, labels, output groups, pruning disabled around processors/plugins | `tests/compile_metadata_test.bzl` |
| KotlinBuilder | Flag parsing, native/legacy routing, ABI/jdeps plans, strict-deps classifications, worker protocol | `tests/kotlin_builder/` |
| Python adapter | Runtime identity/version, launcher and stdlib/helper input closure | `tests/python_toolchain_test.bzl` |
| Kotlin/Java interoperability | Stock Java compile and runtime consumers inherit Kotlin stdlib through JavaInfo, including transitive exports, across worker and ABI modes | `e2e/integration/verify_kotlin_interop.py` |
| JVM execution | Javadoc HTML, fixed archive timestamps, binding symbols, bytecode/dependency text, unused-vs-used reports in worker and one-shot modes | `e2e/integration/verify_jvm_tools.py` |
| ABI strategy selection | Per-target overrides of enabled/disabled global settings, compile/runtime jar separation, and eligibility fallbacks in both languages | `tests/abi_mode_test.bzl` |
| Combined ABI emission | Header digests, runtime outputs, body/API/constant/inline/resource edits, worker and one-shot modes, pruning, per-target combined mode with global ABI flags disabled, and Java classpath-cache reuse across consumer edits and invalidation across dependency edits | `e2e/integration/verify_fused_abi.py` |
| Pruning correctness | Changing unused dependency ABI skips consumer compilation; changing used dependency ABI rebuilds it | `e2e/integration/verify_pruning.py` |
| Processor execution | Generated Java/Kotlin compiled into output jars, processor options/resources, source jars, ABI and jdeps outputs | `e2e/kotlin_builder/verify_outputs.py` |
| Python execution | Transitive imports, data, runtime identity, module mode, arguments, child exit codes, expected Bazel test failure, environment isolation, Python-version selection | `e2e/python_overlay/` |

Run `tools/verify_integrations.sh all` from the repository root for the supported
real-runtime fixtures, or choose `jvm`, `kotlin`, or `python`. See
[CONTRIBUTING.md](../CONTRIBUTING.md) for the faster root test commands.

## Repository security checks

`security.yml` runs on contributions, main pushes, and a weekly schedule. It
uses zizmor (without CodeQL), ShellCheck for release/integration entrypoints,
and `tools/repository_policy_test.py` plus the SBOM helper tests. The policy
checks cover token defaults, checkout credentials, action pins, exact BCR tag
exceptions, forbidden privileged triggers, and Scorecard Git-mode visibility.
Run them with the pinned tools in `requirements-dev.txt`.

## What CI runs

Pull requests get analysis tests on Linux/macOS with Bazel 8/9, smoke analysis,
lint, and generated-doc freshness. The separate RBE job requires the configured
BuildBuddy secret and is gated to trusted events.

Main pushes additionally run KotlinBuilder unit/protocol execution, the JVM
output/pruning checks, full native KAPT/KSP fixtures, and Python integration.
Those jobs use the same integration runner as local development. Real processor
and Python adapter fixtures currently select Linux x86_64 explicitly.

## Remaining gaps

- Native-image execution remains outside the passing integration runner.
- The Elide-themed Javadoc doclet is missing from the published 1.6.2 archive;
  only the standard theme has real execution coverage. Custom doclets need a
  dedicated execution fixture.
- Python native wheels, coverage, precompiled bytecode, zip executables, macOS
  runtime execution, and manifest-only/Windows layouts are not validated.
- RBE coverage does not establish that every new tool or the Python runtime
  works remotely. Version/platform pins are not platform execution tests.
- Dependency-pruning cache behavior is exercised with a Java graph. Mixed
  language and Kotlin pruning have action/report coverage but need equivalent
  cache-invalidation experiments. The Java fixture uses separate packages;
  javac may conservatively retain dependencies discovered in the same package.
- The native-image and standalone ABI/IC soundness harnesses in `e2e/` are
  separate experiments; they are not silently counted as passing CI checks.

Keep this distinction when changing support claims or publishing benchmarks.

The JVM integration runner also checks experimental combined Java and Kotlin ABI emission.
It builds and executes three-target graphs in worker and one-shot modes, with
pruning both enabled and disabled: body edits
preserve the header and skip the consumer, constants/inline bodies/public methods
invalidate it, and no-op builds execute no compiler actions. Every case checks
runtime output, including reuse of a previously compiled consumer after a body
edit. Analysis tests cover conservative fallback for mixed sources, resources,
plugins, exported processors, friends, and incremental compilation.

The Java combined-emission graph packages a resource that the executable reads.
A resource-only edit changes runtime output while executing no compiler actions.
Java analysis tests cover library/binary/test providers, worker/one-shot argv,
ignored combined emission when ABI avoidance is off, and conservative fallbacks.

A separate consumer uses only Java constants or Kotlin constants/inline functions,
leaving no runtime reference to the dependency. Its compiled output and execution
must still update after compile-time values change, including with pruning enabled.

Native Kotlin IC has a real-toolchain regression in
`e2e/integration/verify_incremental.py`, run by the JVM integration suite. It
checks complete output after body edits, deleted nested classes, added/deleted
sources, failed compilation and recovery, dependency constant changes, compiler
option changes, and worker restart. Runtime assertions and jar-content checks run
with persistent workers, sandboxed workers, and one-shot execution. The standalone
`e2e/ic_correctness/output_recreation.py` intentionally remains a failing guard
against the underlying Elide 1.6.2 behavior; native rules use the adapter to avoid
that output/cache lifecycle.

The IC integration guard also restores an older jar from Bazel's disk action
cache while the worker retains newer private state, then edits again. Execution
logs must prove the cache hit and subsequent compiler execution; runtime results,
deleted nested classes, and cold-build equivalence must still match.
