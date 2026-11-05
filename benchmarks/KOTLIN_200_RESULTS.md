# Kotlin comparison with stock ABI mode

[Hosted run 41944028885](https://github.com/elide-dev/rules_elide/actions/runs/41944028885)
completed at `bb352283a2c3634c07bb8cca1c139b62acc7e52b`: 88 cases and 264 measured
samples, three samples after one warm-up per case. This uses 200 **generated**
Core sources, three clients, fresh Bazel servers per mode, and trace collection.
It isolates build behavior; it is not evidence from a real Kotlin application.

Combined emission's median body-edit time was 0.492 s versus 0.746 s for stock
Kotlin with ABI mode and 1.058 s for stock defaults. But combined emission's
public-API edit took 0.744 s versus 0.597 s for stock defaults; multi-module API
edits took 1.132 s versus 0.703 s. Adding pruning reduced those Elide medians to
0.666 s and 0.973 s, respectively: both still slower than stock defaults.
Stock ABI mode also regressed several API edits relative to its default mode.
No single configuration won every scenario. All modes and regressions follow.

[Raw samples](data/kotlin-200-2026-11-05.json) retain actions and trace summaries.
The workflow artifact retains raw execution logs and profiles for 30 days.
Memory counters are complete bucket averages, not peak RSS, and short samples
may have no usable memory measurement. Do not compare these timings directly
with earlier unprofiled runs that shared worker pools across modes.

# Incremental dependency-graph benchmark

Commit: `bb352283a2c3634c07bb8cca1c139b62acc7e52b`

Times include Bazel invocation, analysis, compilation, and execution-log overhead.
Shared action caches and remote execution are disabled. Every edit starts from a rebuilt pristine graph.
Warm-ups are discarded. Counts include full source compiler actions only; ABI/header actions are reported separately.

| Language | Mode | Edit | Mean (s) | Median (s) | Stddev (s) | Full compile targets per sample |
| --- | --- | --- | ---: | ---: | ---: | --- |
| kotlin | vanilla | no_op | 0.186 | 0.198 | 0.025 | none |
| kotlin | vanilla | comment | 0.831 | 0.785 | 0.096 | //core:core |
| kotlin | vanilla | body | 1.176 | 1.058 | 0.308 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla | private_member | 1.003 | 0.996 | 0.036 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla | internal_module_api | 0.890 | 0.882 | 0.028 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla | public_module_api | 0.567 | 0.597 | 0.092 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | vanilla | multi_file_body | 0.780 | 0.791 | 0.102 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla | multi_module_body | 0.717 | 0.650 | 0.129 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla | multi_module_api | 0.718 | 0.703 | 0.042 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla | unused_dependency_api | 0.605 | 0.595 | 0.059 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade, //spare:spare |
| kotlin | vanilla | inline_or_constant | 0.695 | 0.634 | 0.152 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla_abi | no_op | 0.207 | 0.184 | 0.057 | none |
| kotlin | vanilla_abi | comment | 0.935 | 0.897 | 0.074 | //core:core |
| kotlin | vanilla_abi | body | 0.755 | 0.746 | 0.038 | //core:core |
| kotlin | vanilla_abi | private_member | 0.601 | 0.555 | 0.098 | //core:core |
| kotlin | vanilla_abi | internal_module_api | 1.256 | 1.238 | 0.053 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla_abi | public_module_api | 0.782 | 0.794 | 0.072 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | vanilla_abi | multi_file_body | 0.549 | 0.564 | 0.044 | //core:core |
| kotlin | vanilla_abi | multi_module_body | 0.760 | 0.766 | 0.045 | //core:core, //facade:facade |
| kotlin | vanilla_abi | multi_module_api | 1.078 | 1.072 | 0.012 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla_abi | unused_dependency_api | 0.833 | 0.777 | 0.148 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade, //spare:spare |
| kotlin | vanilla_abi | inline_or_constant | 1.037 | 1.006 | 0.125 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide | no_op | 0.236 | 0.257 | 0.037 | none |
| kotlin | elide | comment | 0.541 | 0.530 | 0.058 | //core:core |
| kotlin | elide | body | 1.228 | 1.218 | 0.029 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide | private_member | 1.123 | 1.121 | 0.046 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide | internal_module_api | 1.124 | 1.135 | 0.028 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide | public_module_api | 0.742 | 0.744 | 0.005 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | elide | multi_file_body | 1.033 | 0.988 | 0.109 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide | multi_module_body | 1.227 | 1.279 | 0.121 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide | multi_module_api | 1.128 | 1.120 | 0.022 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide | unused_dependency_api | 0.891 | 0.900 | 0.027 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade, //spare:spare |
| kotlin | elide | inline_or_constant | 1.093 | 1.089 | 0.008 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide_abi | no_op | 0.217 | 0.230 | 0.024 | none |
| kotlin | elide_abi | comment | 0.589 | 0.614 | 0.064 | //core:core |
| kotlin | elide_abi | body | 0.624 | 0.623 | 0.049 | //core:core |
| kotlin | elide_abi | private_member | 0.572 | 0.585 | 0.058 | //core:core |
| kotlin | elide_abi | internal_module_api | 1.257 | 1.261 | 0.034 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide_abi | public_module_api | 0.833 | 0.824 | 0.019 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | elide_abi | multi_file_body | 0.523 | 0.529 | 0.022 | //core:core |
| kotlin | elide_abi | multi_module_body | 0.745 | 0.761 | 0.058 | //core:core, //facade:facade |
| kotlin | elide_abi | multi_module_api | 1.244 | 1.196 | 0.127 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide_abi | unused_dependency_api | 0.933 | 0.920 | 0.025 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade, //spare:spare |
| kotlin | elide_abi | inline_or_constant | 1.259 | 1.220 | 0.086 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide_pruned | no_op | 0.210 | 0.200 | 0.036 | none |
| kotlin | elide_pruned | comment | 0.640 | 0.630 | 0.053 | //core:core |
| kotlin | elide_pruned | body | 0.608 | 0.596 | 0.062 | //core:core |
| kotlin | elide_pruned | private_member | 0.620 | 0.632 | 0.055 | //core:core |
| kotlin | elide_pruned | internal_module_api | 0.753 | 0.759 | 0.027 | //core:core, //facade:facade |
| kotlin | elide_pruned | public_module_api | 0.785 | 0.809 | 0.046 | //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | elide_pruned | multi_file_body | 0.566 | 0.565 | 0.002 | //core:core |
| kotlin | elide_pruned | multi_module_body | 0.759 | 0.781 | 0.047 | //core:core, //facade:facade |
| kotlin | elide_pruned | multi_module_api | 1.227 | 1.193 | 0.077 | //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide_pruned | unused_dependency_api | 0.293 | 0.296 | 0.013 | //spare:spare |
| kotlin | elide_pruned | inline_or_constant | 0.745 | 0.727 | 0.053 | //core:core, //facade:facade |
| kotlin | elide_incremental | no_op | 0.251 | 0.218 | 0.061 | none |
| kotlin | elide_incremental | comment | 0.608 | 0.621 | 0.025 | //core:core |
| kotlin | elide_incremental | body | 0.660 | 0.624 | 0.075 | //core:core |
| kotlin | elide_incremental | private_member | 0.589 | 0.579 | 0.026 | //core:core |
| kotlin | elide_incremental | internal_module_api | 1.290 | 1.272 | 0.060 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide_incremental | public_module_api | 0.917 | 0.913 | 0.009 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | elide_incremental | multi_file_body | 0.601 | 0.585 | 0.038 | //core:core |
| kotlin | elide_incremental | multi_module_body | 0.988 | 0.999 | 0.037 | //core:core, //facade:facade |
| kotlin | elide_incremental | multi_module_api | 1.475 | 1.504 | 0.163 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide_incremental | unused_dependency_api | 1.050 | 1.023 | 0.142 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade, //spare:spare |
| kotlin | elide_incremental | inline_or_constant | 1.242 | 1.200 | 0.090 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide_fused | no_op | 0.215 | 0.213 | 0.008 | none |
| kotlin | elide_fused | comment | 0.552 | 0.542 | 0.024 | //core:core |
| kotlin | elide_fused | body | 0.487 | 0.492 | 0.008 | //core:core |
| kotlin | elide_fused | private_member | 0.496 | 0.498 | 0.010 | //core:core |
| kotlin | elide_fused | internal_module_api | 1.142 | 1.125 | 0.037 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide_fused | public_module_api | 0.750 | 0.744 | 0.016 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | elide_fused | multi_file_body | 0.564 | 0.557 | 0.027 | //core:core |
| kotlin | elide_fused | multi_module_body | 0.645 | 0.643 | 0.039 | //core:core, //facade:facade |
| kotlin | elide_fused | multi_module_api | 1.175 | 1.132 | 0.077 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide_fused | unused_dependency_api | 0.849 | 0.865 | 0.040 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade, //spare:spare |
| kotlin | elide_fused | inline_or_constant | 1.136 | 1.143 | 0.091 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide_fused_pruned | no_op | 0.222 | 0.223 | 0.004 | none |
| kotlin | elide_fused_pruned | comment | 0.551 | 0.556 | 0.029 | //core:core |
| kotlin | elide_fused_pruned | body | 0.515 | 0.521 | 0.022 | //core:core |
| kotlin | elide_fused_pruned | private_member | 0.571 | 0.581 | 0.037 | //core:core |
| kotlin | elide_fused_pruned | internal_module_api | 0.686 | 0.666 | 0.036 | //core:core, //facade:facade |
| kotlin | elide_fused_pruned | public_module_api | 0.655 | 0.666 | 0.019 | //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | elide_fused_pruned | multi_file_body | 0.548 | 0.538 | 0.049 | //core:core |
| kotlin | elide_fused_pruned | multi_module_body | 0.662 | 0.661 | 0.056 | //core:core, //facade:facade |
| kotlin | elide_fused_pruned | multi_module_api | 0.964 | 0.973 | 0.042 | //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide_fused_pruned | unused_dependency_api | 0.276 | 0.261 | 0.039 | //spare:spare |
| kotlin | elide_fused_pruned | inline_or_constant | 0.615 | 0.621 | 0.009 | //core:core, //facade:facade |

## Trace metrics

Memory values are maximum complete bucket averages across measured samples, not process peak RSS.
Bazel memory is heap plus non-heap; worker memory excludes non-worker actions. Missing counters are n/a.

| Language | Mode | Edit | Mean critical-path span (s) | Worker memory (MiB) | Bazel heap + non-heap (MiB) |
| --- | --- | --- | ---: | ---: | ---: |
| kotlin | vanilla | no_op | 0.001 | n/a | n/a |
| kotlin | vanilla | comment | 0.661 | n/a | n/a |
| kotlin | vanilla | body | 1.030 | 944.1 | 236.3 |
| kotlin | vanilla | private_member | 0.877 | n/a | n/a |
| kotlin | vanilla | internal_module_api | 0.759 | n/a | n/a |
| kotlin | vanilla | public_module_api | 0.449 | n/a | n/a |
| kotlin | vanilla | multi_file_body | 0.667 | n/a | n/a |
| kotlin | vanilla | multi_module_body | 0.604 | n/a | n/a |
| kotlin | vanilla | multi_module_api | 0.607 | n/a | n/a |
| kotlin | vanilla | unused_dependency_api | 0.504 | n/a | n/a |
| kotlin | vanilla | inline_or_constant | 0.579 | n/a | n/a |
| kotlin | vanilla_abi | no_op | 0.001 | n/a | n/a |
| kotlin | vanilla_abi | comment | 0.765 | n/a | n/a |
| kotlin | vanilla_abi | body | 0.619 | n/a | n/a |
| kotlin | vanilla_abi | private_member | 0.469 | n/a | n/a |
| kotlin | vanilla_abi | internal_module_api | 1.138 | 1100.0 | 294.4 |
| kotlin | vanilla_abi | public_module_api | 0.633 | n/a | n/a |
| kotlin | vanilla_abi | multi_file_body | 0.435 | n/a | n/a |
| kotlin | vanilla_abi | multi_module_body | 0.642 | n/a | n/a |
| kotlin | vanilla_abi | multi_module_api | 0.963 | 1057.5 | 324.6 |
| kotlin | vanilla_abi | unused_dependency_api | 0.704 | n/a | n/a |
| kotlin | vanilla_abi | inline_or_constant | 0.915 | 840.6 | 279.6 |
| kotlin | elide | no_op | 0.001 | n/a | n/a |
| kotlin | elide | comment | 0.342 | n/a | n/a |
| kotlin | elide | body | 0.984 | 333.0 | 350.1 |
| kotlin | elide | private_member | 0.884 | 310.6 | 350.9 |
| kotlin | elide | internal_module_api | 0.892 | 327.0 | 308.1 |
| kotlin | elide | public_module_api | 0.534 | n/a | n/a |
| kotlin | elide | multi_file_body | 0.826 | 343.4 | 350.5 |
| kotlin | elide | multi_module_body | 1.000 | 354.0 | 336.8 |
| kotlin | elide | multi_module_api | 0.915 | 332.2 | 283.9 |
| kotlin | elide | unused_dependency_api | 0.679 | n/a | n/a |
| kotlin | elide | inline_or_constant | 0.864 | n/a | n/a |
| kotlin | elide_abi | no_op | 0.001 | n/a | n/a |
| kotlin | elide_abi | comment | 0.386 | n/a | n/a |
| kotlin | elide_abi | body | 0.458 | n/a | n/a |
| kotlin | elide_abi | private_member | 0.403 | n/a | n/a |
| kotlin | elide_abi | internal_module_api | 0.945 | 665.1 | 550.0 |
| kotlin | elide_abi | public_module_api | 0.532 | n/a | n/a |
| kotlin | elide_abi | multi_file_body | 0.374 | n/a | n/a |
| kotlin | elide_abi | multi_module_body | 0.554 | n/a | n/a |
| kotlin | elide_abi | multi_module_api | 0.956 | 617.4 | 483.6 |
| kotlin | elide_abi | unused_dependency_api | 0.652 | n/a | n/a |
| kotlin | elide_abi | inline_or_constant | 0.923 | 648.9 | 557.0 |
| kotlin | elide_pruned | no_op | 0.001 | n/a | n/a |
| kotlin | elide_pruned | comment | 0.418 | n/a | n/a |
| kotlin | elide_pruned | body | 0.433 | n/a | n/a |
| kotlin | elide_pruned | private_member | 0.447 | n/a | n/a |
| kotlin | elide_pruned | internal_module_api | 0.550 | n/a | n/a |
| kotlin | elide_pruned | public_module_api | 0.517 | n/a | n/a |
| kotlin | elide_pruned | multi_file_body | 0.407 | n/a | n/a |
| kotlin | elide_pruned | multi_module_body | 0.571 | n/a | n/a |
| kotlin | elide_pruned | multi_module_api | 0.964 | 679.4 | 464.9 |
| kotlin | elide_pruned | unused_dependency_api | 0.128 | n/a | n/a |
| kotlin | elide_pruned | inline_or_constant | 0.564 | n/a | n/a |
| kotlin | elide_incremental | no_op | 0.001 | n/a | n/a |
| kotlin | elide_incremental | comment | 0.419 | n/a | n/a |
| kotlin | elide_incremental | body | 0.468 | n/a | n/a |
| kotlin | elide_incremental | private_member | 0.396 | n/a | n/a |
| kotlin | elide_incremental | internal_module_api | 0.969 | 772.7 | 330.6 |
| kotlin | elide_incremental | public_module_api | 0.513 | n/a | n/a |
| kotlin | elide_incremental | multi_file_body | 0.428 | n/a | n/a |
| kotlin | elide_incremental | multi_module_body | 0.758 | n/a | n/a |
| kotlin | elide_incremental | multi_module_api | 0.996 | 1171.0 | 590.9 |
| kotlin | elide_incremental | unused_dependency_api | 0.665 | n/a | n/a |
| kotlin | elide_incremental | inline_or_constant | 0.805 | 1303.4 | 569.4 |
| kotlin | elide_fused | no_op | 0.001 | n/a | n/a |
| kotlin | elide_fused | comment | 0.365 | n/a | n/a |
| kotlin | elide_fused | body | 0.341 | n/a | n/a |
| kotlin | elide_fused | private_member | 0.343 | n/a | n/a |
| kotlin | elide_fused | internal_module_api | 0.917 | 333.2 | 293.2 |
| kotlin | elide_fused | public_module_api | 0.556 | n/a | n/a |
| kotlin | elide_fused | multi_file_body | 0.417 | n/a | n/a |
| kotlin | elide_fused | multi_module_body | 0.491 | n/a | n/a |
| kotlin | elide_fused | multi_module_api | 0.972 | 339.9 | 364.7 |
| kotlin | elide_fused | unused_dependency_api | 0.654 | n/a | n/a |
| kotlin | elide_fused | inline_or_constant | 0.926 | 314.8 | 344.5 |
| kotlin | elide_fused_pruned | no_op | 0.001 | n/a | n/a |
| kotlin | elide_fused_pruned | comment | 0.360 | n/a | n/a |
| kotlin | elide_fused_pruned | body | 0.357 | n/a | n/a |
| kotlin | elide_fused_pruned | private_member | 0.418 | n/a | n/a |
| kotlin | elide_fused_pruned | internal_module_api | 0.503 | n/a | n/a |
| kotlin | elide_fused_pruned | public_module_api | 0.460 | n/a | n/a |
| kotlin | elide_fused_pruned | multi_file_body | 0.401 | n/a | n/a |
| kotlin | elide_fused_pruned | multi_module_body | 0.512 | n/a | n/a |
| kotlin | elide_fused_pruned | multi_module_api | 0.761 | n/a | n/a |
| kotlin | elide_fused_pruned | unused_dependency_api | 0.100 | n/a | n/a |
| kotlin | elide_fused_pruned | inline_or_constant | 0.464 | n/a | n/a |
