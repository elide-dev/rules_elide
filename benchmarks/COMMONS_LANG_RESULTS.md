# Commons Lang incremental compilation comparison

[Hosted run 41946441246](https://github.com/elide-dev/rules_elide/actions/runs/41946441246)
completed at `0f5d8960d1b50c23058794de6c87a43174f3f91a`: 42 cases, five measured
samples after one warm-up per case (210 measured samples). It compiles 259 real
Apache Commons Lang source files behind a generated facade/client/application
graph. Both compiler paths target Java 21; every classfile version and the
consumer program's result are checked outside timing.

**Stock rules_java had the lowest median in every scenario in this run.**
Body-edit medians were 1.116 s stock, 1.425 s native Elide defaults, and 1.631 s
Elide combined ABI emission. All three recompiled only the production library.
Combined emission with pruning improved the additive facade API edit to 0.398 s,
versus 0.458 s without pruning, but stock still took 0.305 s. ABI avoidance and
pruning alone do not close this workload's compiler throughput gap.

This run predates removal of LLVM and static-linking libraries from compiler
action inputs. It is a baseline for that change, not evidence of its effect.
It also predates the clean-rebuild scenario. The table includes all configurations
and regressions, not just the best Elide result per edit.

Stock Error Prone checks were disabled to compile the upstream source; Elide
does not run Error Prone. This is therefore not static-analysis feature parity.
Elide and rule versions, source revision/digest, host, and all samples are recorded in
[the raw data](data/commons-lang-2026-11-05.json). The actual Commons Lang module
is production code, but consumers are generated and upstream tests are not run.

Sequential mode order and shared hosted hardware limit small timing comparisons.
Profiles were collected for both compilers. Memory figures are complete bucket
averages, not peak RSS; absent samples mean unknown. The workflow artifact retains
raw execution logs and profiles for 30 days.

# Incremental dependency-graph benchmark

Commit: `0f5d8960d1b50c23058794de6c87a43174f3f91a`

Production sources: Apache Commons Lang at `67cbf817b6af58fc168d26774186e889bb9efe50`; 259 Java files.
Source SHA-256: `cfe6326f42939b19217f16fc1f78185d739d21274ce81ace7aebd0f3f27e428e`; checkout dirty: `False`.
The downstream consumer graph is generated. Runtime assertions run outside build timing.

Times include Bazel invocation, analysis, compilation, and execution-log overhead.
Shared action caches and remote execution are disabled. Every edit starts from a rebuilt pristine graph.
Warm-ups are discarded. Counts include full source compiler actions only; ABI/header actions are reported separately.

| Language | Mode | Edit | Mean (s) | Median (s) | Stddev (s) | Full compile targets per sample |
| --- | --- | --- | ---: | ---: | ---: | --- |
| java | vanilla | no_op | 0.202 | 0.199 | 0.029 | none |
| java | vanilla | comment | 1.302 | 1.256 | 0.137 | //core:core |
| java | vanilla | body | 1.097 | 1.116 | 0.074 | //core:core |
| java | vanilla | private_member | 1.068 | 1.058 | 0.034 | //core:core |
| java | vanilla | internal_module_api | 1.194 | 1.185 | 0.036 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| java | vanilla | public_module_api | 0.300 | 0.305 | 0.016 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| java | vanilla | multi_file_body | 1.076 | 1.077 | 0.038 | //core:core |
| java | elide | no_op | 0.279 | 0.257 | 0.053 | none |
| java | elide | comment | 1.530 | 1.494 | 0.095 | //core:core |
| java | elide | body | 1.434 | 1.425 | 0.037 | //core:core |
| java | elide | private_member | 1.410 | 1.401 | 0.017 | //core:core |
| java | elide | internal_module_api | 1.883 | 1.863 | 0.050 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| java | elide | public_module_api | 0.487 | 0.488 | 0.031 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| java | elide | multi_file_body | 1.738 | 1.749 | 0.119 | //core:core |
| java | elide_abi | no_op | 0.228 | 0.236 | 0.041 | none |
| java | elide_abi | comment | 1.515 | 1.442 | 0.128 | //core:core |
| java | elide_abi | body | 1.428 | 1.425 | 0.014 | //core:core |
| java | elide_abi | private_member | 1.464 | 1.456 | 0.038 | //core:core |
| java | elide_abi | internal_module_api | 1.890 | 1.881 | 0.033 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| java | elide_abi | public_module_api | 0.511 | 0.502 | 0.021 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| java | elide_abi | multi_file_body | 1.759 | 1.718 | 0.158 | //core:core |
| java | elide_pruned | no_op | 0.215 | 0.208 | 0.030 | none |
| java | elide_pruned | comment | 1.616 | 1.594 | 0.120 | //core:core |
| java | elide_pruned | body | 1.644 | 1.652 | 0.092 | //core:core |
| java | elide_pruned | private_member | 1.612 | 1.637 | 0.110 | //core:core |
| java | elide_pruned | internal_module_api | 1.814 | 1.810 | 0.058 | //core:core, //facade:facade |
| java | elide_pruned | public_module_api | 0.516 | 0.518 | 0.022 | //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| java | elide_pruned | multi_file_body | 1.865 | 1.863 | 0.154 | //core:core |
| java | elide_fused | no_op | 0.227 | 0.218 | 0.036 | none |
| java | elide_fused | comment | 1.653 | 1.656 | 0.070 | //core:core |
| java | elide_fused | body | 1.627 | 1.631 | 0.054 | //core:core |
| java | elide_fused | private_member | 1.597 | 1.602 | 0.041 | //core:core |
| java | elide_fused | internal_module_api | 1.929 | 1.909 | 0.055 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| java | elide_fused | public_module_api | 0.542 | 0.458 | 0.201 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| java | elide_fused | multi_file_body | 1.639 | 1.559 | 0.181 | //core:core |
| java | elide_fused_pruned | no_op | 0.243 | 0.244 | 0.009 | none |
| java | elide_fused_pruned | comment | 1.675 | 1.677 | 0.091 | //core:core |
| java | elide_fused_pruned | body | 1.649 | 1.632 | 0.027 | //core:core |
| java | elide_fused_pruned | private_member | 1.673 | 1.635 | 0.063 | //core:core |
| java | elide_fused_pruned | internal_module_api | 1.732 | 1.694 | 0.066 | //core:core, //facade:facade |
| java | elide_fused_pruned | public_module_api | 0.403 | 0.398 | 0.018 | //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| java | elide_fused_pruned | multi_file_body | 1.522 | 1.526 | 0.032 | //core:core |

## Trace metrics

Memory values are maximum complete bucket averages across measured samples, not process peak RSS.
Bazel memory is heap plus non-heap; worker memory excludes non-worker actions. Missing counters are n/a.

| Language | Mode | Edit | Mean critical-path span (s) | Worker memory (MiB) | Bazel heap + non-heap (MiB) |
| --- | --- | --- | ---: | ---: | ---: |
| java | vanilla | no_op | 0.001 | n/a | n/a |
| java | vanilla | comment | 1.142 | 717.5 | 361.8 |
| java | vanilla | body | 0.963 | 553.9 | 373.6 |
| java | vanilla | private_member | 0.939 | 431.7 | 341.6 |
| java | vanilla | internal_module_api | 1.068 | 1208.1 | 373.8 |
| java | vanilla | public_module_api | 0.155 | n/a | n/a |
| java | vanilla | multi_file_body | 0.957 | 618.4 | 341.6 |
| java | elide | no_op | 0.001 | n/a | n/a |
| java | elide | comment | 1.319 | 359.6 | 265.2 |
| java | elide | body | 1.256 | 355.6 | 225.4 |
| java | elide | private_member | 1.232 | 334.8 | 234.0 |
| java | elide | internal_module_api | 1.605 | 350.8 | 335.0 |
| java | elide | public_module_api | 0.242 | n/a | n/a |
| java | elide | multi_file_body | 1.580 | 364.4 | 360.0 |
| java | elide_abi | no_op | 0.001 | n/a | n/a |
| java | elide_abi | comment | 1.312 | 581.0 | 335.2 |
| java | elide_abi | body | 1.245 | 564.2 | 345.2 |
| java | elide_abi | private_member | 1.279 | 523.6 | 333.6 |
| java | elide_abi | internal_module_api | 1.454 | 562.8 | 488.8 |
| java | elide_abi | public_module_api | 0.219 | n/a | n/a |
| java | elide_abi | multi_file_body | 1.585 | 541.2 | 539.2 |
| java | elide_pruned | no_op | 0.001 | n/a | n/a |
| java | elide_pruned | comment | 1.388 | 597.9 | 331.0 |
| java | elide_pruned | body | 1.446 | 605.3 | 307.2 |
| java | elide_pruned | private_member | 1.414 | 625.5 | 306.6 |
| java | elide_pruned | internal_module_api | 1.523 | 732.0 | 292.7 |
| java | elide_pruned | public_module_api | 0.181 | n/a | n/a |
| java | elide_pruned | multi_file_body | 1.683 | 655.8 | 300.8 |
| java | elide_fused | no_op | 0.001 | n/a | n/a |
| java | elide_fused | comment | 1.445 | 386.0 | 239.0 |
| java | elide_fused | body | 1.446 | 425.3 | 217.0 |
| java | elide_fused | private_member | 1.428 | 481.0 | 380.0 |
| java | elide_fused | internal_module_api | 1.671 | 488.6 | 323.4 |
| java | elide_fused | public_module_api | 0.257 | n/a | n/a |
| java | elide_fused | multi_file_body | 1.476 | 349.5 | 386.4 |
| java | elide_fused_pruned | no_op | 0.001 | n/a | n/a |
| java | elide_fused_pruned | comment | 1.482 | 392.5 | 301.2 |
| java | elide_fused_pruned | body | 1.463 | 457.9 | 307.8 |
| java | elide_fused_pruned | private_member | 1.501 | 534.0 | 315.8 |
| java | elide_fused_pruned | internal_module_api | 1.539 | 531.6 | 376.8 |
| java | elide_fused_pruned | public_module_api | 0.199 | n/a | n/a |
| java | elide_fused_pruned | multi_file_body | 1.360 | 352.2 | 406.6 |
