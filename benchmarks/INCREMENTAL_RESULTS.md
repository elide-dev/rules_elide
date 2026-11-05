# Incremental results: 2026-11-04

[Hosted run and raw execution logs](https://github.com/elide-dev/rules_elide/actions/runs/41936250282).
[Structured timing/action data](data/incremental-2026-11-04.json).

Commit `5064e321bb678b50cc76b3c9ac02d66c7c8561b9`; Elide 1.6.2, Bazel 9.3.1,
rules_java 9.9.0, rules_kotlin 2.4.21. Ubuntu x86_64 hosted runner, four CPUs/jobs.
Core has 20 files; Facade fans out to three clients, then App. Three measured
samples per case after one discarded warm-up; 99 cases and 297 timed samples.
See [methodology and scenario definitions](INCREMENTAL.md).

## Findings

- Kotlin ABI mode reduced body-only, private-member, and same-module multi-file
  edits from six full compiler actions to one. Body-only mean latency fell from
  1.118s (vanilla) to 0.360s (ABI mode), about 3.1x faster.
- Pruning limited internal API changes to Core + Facade, and unused dependency
  changes to Spare. These action patterns were identical across all three samples.
- ABI mode alone did not stop transitive classpath changes from reaching the
  whole chain after a public API change. Pruning and ABI compilation solve
  different parts of the problem.
- Fewer compiler actions did not guarantee lower latency. Java pruning overhead
  often erased the savings on this small graph. Public facade API and multi-module
  API changes were slower with Elide optimizations than vanilla in this run.
- Kotlin experimental incremental compilation plus ABI was slower than ABI-only
  on these 20-file modules (body-only: 0.604s vs 0.360s). This does not establish
  its behavior on large modules; action logs cannot count dirty files inside IC.

Keep these options opt-in. Repeat larger real-project measurements before
changing defaults. No-op means ranged from 0.136s to 0.267s across modes, showing
that Bazel overhead and hosted-runner variability are significant at this scale.
Modes ran sequentially, so small latency differences are not strong evidence.
These are end-to-end build times with execution logging, not compiler-only times.
Recompilation patterns are not a proof of runtime/ABI correctness.

## Java

Cells are **mean seconds / number of full compiler targets**. ABI/header
actions are additional; their targets and all sample timings are in the JSON.

| Edit | Vanilla | Elide default | ABI | ABI + pruning |
| --- | ---: | ---: | ---: | ---: |
| no_op | 0.192 / 0 | 0.155 / 0 | 0.159 / 0 | 0.267 / 0 |
| comment | 0.291 / 1 | 0.206 / 1 | 0.248 / 1 | 0.367 / 1 |
| body | 0.254 / 1 | 0.222 / 1 | 0.258 / 1 | 0.267 / 1 |
| private_member | 0.230 / 1 | 0.231 / 1 | 0.234 / 1 | 0.262 / 1 |
| internal_module_api | 0.489 / 6 | 0.447 / 6 | 0.876 / 6 | 0.473 / 2 |
| public_module_api | 0.404 / 5 | 0.370 / 5 | 0.488 / 5 | 0.501 / 4 |
| multi_file_body | 0.229 / 1 | 0.209 / 1 | 0.234 / 1 | 0.346 / 1 |
| multi_module_body | 0.279 / 2 | 0.264 / 2 | 0.306 / 2 | 0.334 / 2 |
| multi_module_api | 0.463 / 6 | 0.436 / 6 | 0.689 / 6 | 0.716 / 5 |
| unused_dependency_api | 0.385 / 6 | 0.430 / 6 | 0.671 / 6 | 0.472 / 1 |
| inline_or_constant | 0.582 / 6 | 0.449 / 6 | 0.581 / 6 | 0.473 / 2 |

## Kotlin

Cells are **mean seconds / number of full compiler targets**. ABI/header
actions are additional; their targets and all sample timings are in the JSON.

| Edit | Vanilla | Elide default | ABI | ABI + pruning | ABI + IC |
| --- | ---: | ---: | ---: | ---: | ---: |
| no_op | 0.138 / 0 | 0.151 / 0 | 0.136 / 0 | 0.146 / 0 | 0.198 / 0 |
| comment | 0.480 / 1 | 0.303 / 1 | 0.349 / 1 | 0.370 / 1 | 0.461 / 1 |
| body | 1.118 / 6 | 1.056 / 6 | 0.360 / 1 | 0.410 / 1 | 0.604 / 1 |
| private_member | 1.060 / 6 | 1.127 / 6 | 0.341 / 1 | 0.380 / 1 | 0.542 / 1 |
| internal_module_api | 0.843 / 6 | 1.052 / 6 | 1.423 / 6 | 0.601 / 2 | 1.372 / 6 |
| public_module_api | 0.687 / 5 | 0.929 / 5 | 1.089 / 5 | 0.997 / 4 | 1.165 / 5 |
| multi_file_body | 0.843 / 6 | 1.140 / 6 | 0.356 / 1 | 0.385 / 1 | 0.600 / 1 |
| multi_module_body | 0.753 / 6 | 1.209 / 6 | 0.542 / 2 | 0.567 / 2 | 0.973 / 2 |
| multi_module_api | 0.801 / 6 | 1.136 / 6 | 1.347 / 6 | 1.172 / 5 | 1.390 / 6 |
| unused_dependency_api | 0.732 / 6 | 1.061 / 6 | 1.233 / 6 | 0.346 / 1 | 1.273 / 6 |
| inline_or_constant | 0.787 / 6 | 1.085 / 6 | 1.286 / 6 | 0.577 / 2 | 1.423 / 6 |
