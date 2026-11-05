# Commons Lang clean and incremental builds

[Hosted run 41948512499](https://github.com/elide-dev/rules_elide/actions/runs/41948512499)
completed at `4547aca322a1b2727cccaf6c7d681fbdbecfbbd0`: 48 cases and 240 measured
samples, five after one warm-up per case. This compiles the same 259 production
Commons Lang files and generated consumer graph as the [earlier incremental
comparison](COMMONS_LANG_RESULTS.md), with both sides targeting Java 21.
All runtime outputs and classfile versions are checked outside timing.

Native Elide defaults rebuilt clean in a median **3.341 s versus 7.623 s** for
stock Java (about 2.28 times faster). Cleanup is untimed; dependencies are already
downloaded. This is a `bazel clean` rebuild, not an empty-cache first installation.
All seven runtime targets must execute full compilers, so header-only work cannot
produce an apparent clean-build win.

Warm implementation edits still favor stock: body-edit medians were **1.026 s
stock, 1.421 s native defaults, and 1.486 s combined emission**. Multi-file edits
were 1.012 s stock versus 1.724 s native defaults. Both sides recompile only Core
for these edits. The narrower action input set does not close that throughput gap.

The small facade API edit favored Elide in this run: 0.287 s stock versus 0.269 s
native defaults and 0.244 s combined emission with pruning. These short timings
are sensitive to host and scheduling noise; retain the samples rather than
assuming the ordering generalizes to larger consumers. Stock also retained the
lowest no-op median (0.124 s versus 0.140–0.158 s for the Elide modes).

This commit excludes LLVM and static-linking libraries from compiler inputs.
The earlier run used a different hosted instance; comparisons between runs do
not establish a causal latency improvement from the input reduction. Within
this run, all modes use fresh Bazel servers and identical trace collection.
Stock Error Prone checks are disabled for the upstream code, so static-analysis
feature parity is not measured. Consumers remain generated, not a full real app.

[Raw samples and trace summaries](data/commons-lang-clean-2026-11-05.json) preserve
all modes and regressions. Memory values are complete bucket averages, not peak
RSS. The workflow artifact retains detailed traces and execution logs for 30 days.

# Incremental dependency-graph benchmark

Commit: `4547aca322a1b2727cccaf6c7d681fbdbecfbbd0`

Production sources: Apache Commons Lang at `67cbf817b6af58fc168d26774186e889bb9efe50`; 259 Java files.
Source SHA-256: `cfe6326f42939b19217f16fc1f78185d739d21274ce81ace7aebd0f3f27e428e`; checkout dirty: `False`.
The downstream consumer graph is generated. Runtime assertions run outside build timing.

Times include Bazel invocation, analysis, compilation, and execution-log overhead.
Shared action caches and remote execution are disabled. Every edit starts from a rebuilt pristine graph.
Warm-ups are discarded. Counts include full source compiler actions only; ABI/header actions are reported separately.

| Language | Mode | Edit | Mean (s) | Median (s) | Stddev (s) | Full compile targets per sample |
| --- | --- | --- | ---: | ---: | ---: | --- |
| java | vanilla | clean | 7.736 | 7.623 | 0.205 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade, //spare:spare |
| java | vanilla | no_op | 0.132 | 0.124 | 0.017 | none |
| java | vanilla | comment | 1.248 | 1.201 | 0.182 | //core:core |
| java | vanilla | body | 1.068 | 1.026 | 0.081 | //core:core |
| java | vanilla | private_member | 1.030 | 1.007 | 0.039 | //core:core |
| java | vanilla | internal_module_api | 1.126 | 1.138 | 0.058 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| java | vanilla | public_module_api | 0.290 | 0.287 | 0.019 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| java | vanilla | multi_file_body | 1.015 | 1.012 | 0.040 | //core:core |
| java | elide | clean | 3.572 | 3.341 | 0.442 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade, //spare:spare |
| java | elide | no_op | 0.154 | 0.158 | 0.009 | none |
| java | elide | comment | 1.434 | 1.448 | 0.061 | //core:core |
| java | elide | body | 1.385 | 1.421 | 0.059 | //core:core |
| java | elide | private_member | 1.401 | 1.407 | 0.058 | //core:core |
| java | elide | internal_module_api | 1.589 | 1.596 | 0.033 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| java | elide | public_module_api | 0.296 | 0.269 | 0.062 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| java | elide | multi_file_body | 1.707 | 1.724 | 0.064 | //core:core |
| java | elide_abi | clean | 3.452 | 3.467 | 0.220 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade, //spare:spare |
| java | elide_abi | no_op | 0.145 | 0.144 | 0.006 | none |
| java | elide_abi | comment | 1.398 | 1.360 | 0.071 | //core:core |
| java | elide_abi | body | 1.403 | 1.361 | 0.082 | //core:core |
| java | elide_abi | private_member | 1.465 | 1.461 | 0.073 | //core:core |
| java | elide_abi | internal_module_api | 1.601 | 1.628 | 0.054 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| java | elide_abi | public_module_api | 0.258 | 0.255 | 0.013 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| java | elide_abi | multi_file_body | 1.490 | 1.477 | 0.056 | //core:core |
| java | elide_pruned | clean | 3.551 | 3.531 | 0.278 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade, //spare:spare |
| java | elide_pruned | no_op | 0.146 | 0.146 | 0.012 | none |
| java | elide_pruned | comment | 1.421 | 1.402 | 0.056 | //core:core |
| java | elide_pruned | body | 1.455 | 1.471 | 0.070 | //core:core |
| java | elide_pruned | private_member | 1.464 | 1.463 | 0.055 | //core:core |
| java | elide_pruned | internal_module_api | 1.514 | 1.507 | 0.041 | //core:core, //facade:facade |
| java | elide_pruned | public_module_api | 0.263 | 0.261 | 0.017 | //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| java | elide_pruned | multi_file_body | 1.519 | 1.487 | 0.053 | //core:core |
| java | elide_fused | clean | 3.547 | 3.510 | 0.159 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade, //spare:spare |
| java | elide_fused | no_op | 0.150 | 0.147 | 0.020 | none |
| java | elide_fused | comment | 1.500 | 1.483 | 0.067 | //core:core |
| java | elide_fused | body | 1.475 | 1.486 | 0.091 | //core:core |
| java | elide_fused | private_member | 1.485 | 1.465 | 0.046 | //core:core |
| java | elide_fused | internal_module_api | 1.644 | 1.649 | 0.039 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| java | elide_fused | public_module_api | 0.264 | 0.264 | 0.010 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| java | elide_fused | multi_file_body | 1.446 | 1.435 | 0.044 | //core:core |
| java | elide_fused_pruned | clean | 3.510 | 3.520 | 0.224 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade, //spare:spare |
| java | elide_fused_pruned | no_op | 0.155 | 0.140 | 0.028 | none |
| java | elide_fused_pruned | comment | 1.453 | 1.483 | 0.070 | //core:core |
| java | elide_fused_pruned | body | 1.441 | 1.462 | 0.074 | //core:core |
| java | elide_fused_pruned | private_member | 1.467 | 1.487 | 0.086 | //core:core |
| java | elide_fused_pruned | internal_module_api | 1.531 | 1.531 | 0.036 | //core:core, //facade:facade |
| java | elide_fused_pruned | public_module_api | 0.247 | 0.244 | 0.018 | //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| java | elide_fused_pruned | multi_file_body | 1.486 | 1.508 | 0.048 | //core:core |

## Trace metrics

Memory values are maximum complete bucket averages across measured samples, not process peak RSS.
Bazel memory is heap plus non-heap; worker memory excludes non-worker actions. Missing counters are n/a.

| Language | Mode | Edit | Mean critical-path span (s) | Worker memory (MiB) | Bazel heap + non-heap (MiB) |
| --- | --- | --- | ---: | ---: | ---: |
| java | vanilla | clean | 6.298 | 362.1 | 336.8 |
| java | vanilla | no_op | 0.001 | n/a | n/a |
| java | vanilla | comment | 1.122 | 582.3 | 411.6 |
| java | vanilla | body | 0.947 | 467.7 | 389.6 |
| java | vanilla | private_member | 0.910 | 497.0 | 435.6 |
| java | vanilla | internal_module_api | 1.008 | 590.5 | 392.0 |
| java | vanilla | public_module_api | 0.155 | n/a | n/a |
| java | vanilla | multi_file_body | 0.898 | 557.0 | 306.4 |
| java | elide | clean | 1.494 | 262.1 | 328.6 |
| java | elide | no_op | 0.001 | n/a | n/a |
| java | elide | comment | 1.291 | 372.9 | 526.2 |
| java | elide | body | 1.254 | 385.3 | 504.0 |
| java | elide | private_member | 1.272 | 394.9 | 468.6 |
| java | elide | internal_module_api | 1.440 | 351.0 | 503.6 |
| java | elide | public_module_api | 0.156 | n/a | n/a |
| java | elide | multi_file_body | 1.587 | 444.5 | 563.0 |
| java | elide_abi | clean | 1.398 | 467.1 | 300.1 |
| java | elide_abi | no_op | 0.001 | n/a | n/a |
| java | elide_abi | comment | 1.264 | 612.8 | 533.0 |
| java | elide_abi | body | 1.267 | 577.4 | 451.8 |
| java | elide_abi | private_member | 1.327 | 628.4 | 465.6 |
| java | elide_abi | internal_module_api | 1.373 | 656.6 | 492.0 |
| java | elide_abi | public_module_api | 0.115 | n/a | n/a |
| java | elide_abi | multi_file_body | 1.358 | 681.3 | 464.6 |
| java | elide_pruned | clean | 1.448 | 457.3 | 336.4 |
| java | elide_pruned | no_op | 0.001 | n/a | n/a |
| java | elide_pruned | comment | 1.274 | 582.9 | 658.4 |
| java | elide_pruned | body | 1.317 | 594.9 | 593.2 |
| java | elide_pruned | private_member | 1.329 | 609.1 | 613.6 |
| java | elide_pruned | internal_module_api | 1.366 | 669.8 | 657.8 |
| java | elide_pruned | public_module_api | 0.104 | n/a | n/a |
| java | elide_pruned | multi_file_body | 1.394 | 731.9 | 624.0 |
| java | elide_fused | clean | 1.527 | 284.1 | 289.0 |
| java | elide_fused | no_op | 0.001 | n/a | n/a |
| java | elide_fused | comment | 1.364 | 417.8 | 441.0 |
| java | elide_fused | body | 1.348 | 487.6 | 337.0 |
| java | elide_fused | private_member | 1.357 | 486.9 | 297.8 |
| java | elide_fused | internal_module_api | 1.494 | 516.6 | 339.0 |
| java | elide_fused | public_module_api | 0.126 | n/a | n/a |
| java | elide_fused | multi_file_body | 1.309 | 505.6 | 335.0 |
| java | elide_fused_pruned | clean | 1.553 | 295.4 | 322.7 |
| java | elide_fused_pruned | no_op | 0.001 | n/a | n/a |
| java | elide_fused_pruned | comment | 1.316 | 382.6 | 552.4 |
| java | elide_fused_pruned | body | 1.312 | 455.3 | 578.0 |
| java | elide_fused_pruned | private_member | 1.338 | 470.4 | 548.8 |
| java | elide_fused_pruned | internal_module_api | 1.398 | 458.4 | 501.4 |
| java | elide_fused_pruned | public_module_api | 0.115 | n/a | n/a |
| java | elide_fused_pruned | multi_file_body | 1.358 | 458.6 | 501.6 |
