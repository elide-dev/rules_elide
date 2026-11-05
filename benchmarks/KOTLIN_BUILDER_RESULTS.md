# Production KotlinBuilder clean and incremental builds

[Hosted run 41954649780](https://github.com/elide-dev/rules_elide/actions/runs/41954649780)
passed at `09b7e5650c597b39108ee219dd5eb58794512e4c`: 64 cases and 192 measured
samples, three after one warm-up per case. The fixture compiles this repository's
nine KotlinBuilder Kotlin files and two protocol files, with generated downstream
consumers. Both compilers target JVM 21; runtime assertions and classfile version
checks run outside timing. This is a real tooling module, not a full application
or a timing measurement of the KotlinBuilder toolchain adapter itself.

Combined compilation rebuilt clean in **20.030 s versus 30.031 s** for stock
Kotlin with ABI mode (1.50 times faster). Clean includes rebuilding compiler
adapters and protocol dependencies after untimed `bazel clean`; it excludes
initial downloads. Native incremental compilation's adapter bootstrap brought
its clean median to **31.164 s**, slower than either stock mode.

Implementation edits benefit from ABI avoidance and native incremental state.
Body-edit medians were **0.950 s native incremental, 1.185 s combined, 1.470 s
stock ABI, and 2.226 s stock defaults**. Native incremental also led the measured
comment, private-member, and multi-file implementation edits. These timings now
include complete outputs: the previous incremental output-loss bug is fixed,
and every sample passes consumer runtime checks.

API edits remain a gap. Combined compilation with pruning reduced an internal
module API edit to **1.546 s versus 1.774 s stock defaults and 2.450 s stock ABI**,
by rebuilding Core and Facade instead of the whole consumer graph. For a public
Facade API edit, stock defaults still led: **0.847 s versus 0.904 s combined with
pruning**. Native incremental compilation everywhere was substantially worse:
**3.332 s internal API and 2.151 s public API**. Dependency changes invalidate its
private target state; giving every small consumer an incremental adapter carries
startup and state costs. Selective per-target incremental compilation is a next
experiment, not a demonstrated fix.

Memory is also unresolved. Maximum complete worker-memory bucket averages reached
**3,008.9 MiB** for native incremental public API edits versus **1,348.2 MiB** for
stock ABI in that case. Combined compilation used **863.8 MiB** on body edits
versus **1,240.9 MiB** stock ABI. These are sampled bucket averages, not process
peak RSS; short actions can have no complete bucket. Bazel memory and non-worker
process costs must also be considered. No-op differences of milliseconds do not
establish a stable winner.

The modes run on one hosted machine with separate Bazel servers and identical
trace collection; shared action caches and remote execution are disabled. There
are only three measured samples per case and modes run sequentially. Retain
regressions and avoid extrapolating this one module to all projects. This run
predates the jextract input reduction and the Java classpath-cache eligibility
fix; it cannot measure their effects.

[Raw samples and trace summaries](data/kotlin-builder-2026-11-05.json) retain every
mode. Full execution logs and traces are in the hosted run's artifact.

## Median comparison

Seconds; all eight modes and scenarios are retained.

| Mode | clean | no_op | comment | body | private_member | internal_module_api | public_module_api | multi_file_body |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| vanilla | 30.078 | 0.216 | 2.894 | 2.226 | 2.074 | 1.774 | 0.847 | 1.623 |
| vanilla_abi | 30.031 | 0.227 | 2.093 | 1.470 | 1.540 | 2.450 | 0.992 | 1.138 |
| elide | 20.162 | 0.279 | 1.814 | 2.063 | 1.915 | 2.074 | 0.946 | 2.222 |
| elide_abi | 21.246 | 0.246 | 1.117 | 1.193 | 1.226 | 2.328 | 1.116 | 1.251 |
| elide_pruned | 21.270 | 0.235 | 1.164 | 1.229 | 1.342 | 1.614 | 0.987 | 1.368 |
| elide_incremental | 31.164 | 0.213 | 0.970 | 0.950 | 1.131 | 3.332 | 2.151 | 0.990 |
| elide_fused | 20.030 | 0.246 | 1.125 | 1.185 | 1.237 | 2.114 | 1.030 | 1.265 |
| elide_fused_pruned | 20.769 | 0.232 | 1.152 | 1.307 | 1.327 | 1.546 | 0.904 | 1.236 |

## Full action and trace report

Commit: `09b7e5650c597b39108ee219dd5eb58794512e4c`

Production sources: rules_elide KotlinBuilder at `09b7e5650c597b39108ee219dd5eb58794512e4c`; 11 source files.
Source SHA-256: `71682b146d0a77af9b5159021a8d4ad3f743ce9768ba48a41d9ccb666dc41884`; checkout dirty: `False`.
The downstream consumer graph is generated. Runtime assertions run outside build timing.

Times include Bazel invocation, analysis, compilation, and execution-log overhead.
Shared action caches and remote execution are disabled. Every edit starts from a rebuilt pristine graph.
Warm-ups are discarded. Counts include full source compiler actions only; ABI/header actions are reported separately.

| Language | Mode | Edit | Mean (s) | Median (s) | Stddev (s) | Full compile targets per sample |
| --- | --- | --- | ---: | ---: | ---: | --- |
| kotlin | vanilla | clean | 30.031 | 30.078 | 0.465 | //app:app, //app:verify, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade, //protocol:deps_proto, //protocol:worker_protocol_proto, //spare:spare, @@protobuf+//java/core:core, @@protobuf+//java/core:lite_runtime_only, @@rules_kotlin+//src/main/kotlin:build, @@rules_kotlin+//src/main/kotlin:jdeps_merger |
| kotlin | vanilla | no_op | 0.224 | 0.216 | 0.019 | none |
| kotlin | vanilla | comment | 3.081 | 2.894 | 0.433 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla | body | 2.286 | 2.226 | 0.160 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla | private_member | 2.069 | 2.074 | 0.029 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla | internal_module_api | 1.742 | 1.774 | 0.085 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla | public_module_api | 0.827 | 0.847 | 0.074 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | vanilla | multi_file_body | 1.667 | 1.623 | 0.110 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla_abi | clean | 30.193 | 30.031 | 0.400 | //app:app, //app:verify, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade, //protocol:deps_proto, //protocol:worker_protocol_proto, //spare:spare, @@protobuf+//java/core:core, @@protobuf+//java/core:lite_runtime_only, @@rules_kotlin+//src/main/kotlin:build, @@rules_kotlin+//src/main/kotlin:jdeps_merger |
| kotlin | vanilla_abi | no_op | 0.243 | 0.227 | 0.031 | none |
| kotlin | vanilla_abi | comment | 2.085 | 2.093 | 0.196 | //core:core |
| kotlin | vanilla_abi | body | 1.481 | 1.470 | 0.036 | //core:core |
| kotlin | vanilla_abi | private_member | 1.599 | 1.540 | 0.158 | //core:core |
| kotlin | vanilla_abi | internal_module_api | 2.455 | 2.450 | 0.095 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla_abi | public_module_api | 1.024 | 0.992 | 0.069 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | vanilla_abi | multi_file_body | 1.126 | 1.138 | 0.031 | //core:core |
| kotlin | elide | clean | 20.381 | 20.162 | 0.457 | //app:app, //app:verify, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade, //protocol:deps_proto, //protocol:worker_protocol_proto, //spare:spare, @@protobuf+//java/core:core, @@protobuf+//java/core:lite_runtime_only |
| kotlin | elide | no_op | 0.276 | 0.279 | 0.018 | none |
| kotlin | elide | comment | 1.885 | 1.814 | 0.127 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide | body | 2.073 | 2.063 | 0.035 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide | private_member | 1.993 | 1.915 | 0.147 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide | internal_module_api | 2.091 | 2.074 | 0.038 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide | public_module_api | 0.963 | 0.946 | 0.030 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | elide | multi_file_body | 2.182 | 2.222 | 0.077 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide_abi | clean | 21.223 | 21.246 | 0.173 | //app:app, //app:verify, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade, //protocol:deps_proto, //protocol:worker_protocol_proto, //spare:spare, @@protobuf+//java/core:core, @@protobuf+//java/core:lite_runtime_only |
| kotlin | elide_abi | no_op | 0.247 | 0.246 | 0.023 | none |
| kotlin | elide_abi | comment | 1.117 | 1.117 | 0.005 | //core:core |
| kotlin | elide_abi | body | 1.229 | 1.193 | 0.083 | //core:core |
| kotlin | elide_abi | private_member | 1.252 | 1.226 | 0.056 | //core:core |
| kotlin | elide_abi | internal_module_api | 2.331 | 2.328 | 0.079 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide_abi | public_module_api | 1.130 | 1.116 | 0.056 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | elide_abi | multi_file_body | 1.250 | 1.251 | 0.057 | //core:core |
| kotlin | elide_pruned | clean | 21.076 | 21.270 | 0.630 | //app:app, //app:verify, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade, //protocol:deps_proto, //protocol:worker_protocol_proto, //spare:spare, @@protobuf+//java/core:core, @@protobuf+//java/core:lite_runtime_only |
| kotlin | elide_pruned | no_op | 0.222 | 0.235 | 0.028 | none |
| kotlin | elide_pruned | comment | 1.183 | 1.164 | 0.054 | //core:core |
| kotlin | elide_pruned | body | 1.238 | 1.229 | 0.077 | //core:core |
| kotlin | elide_pruned | private_member | 1.347 | 1.342 | 0.010 | //core:core |
| kotlin | elide_pruned | internal_module_api | 1.634 | 1.614 | 0.060 | //core:core, //facade:facade |
| kotlin | elide_pruned | public_module_api | 0.969 | 0.987 | 0.051 | //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | elide_pruned | multi_file_body | 1.358 | 1.368 | 0.086 | //core:core |
| kotlin | elide_incremental | clean | 31.562 | 31.164 | 0.842 | //app:app, //app:verify, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade, //protocol:deps_proto, //protocol:worker_protocol_proto, //spare:spare, @@protobuf+//java/core:core, @@protobuf+//java/core:lite_runtime_only, @@rules_elide+//elide/kotlin/builder/proto:worker_protocol_proto, @@rules_elide+//elide/private/ic_worker:ic_worker |
| kotlin | elide_incremental | no_op | 0.215 | 0.213 | 0.016 | none |
| kotlin | elide_incremental | comment | 0.959 | 0.970 | 0.034 | //core:core |
| kotlin | elide_incremental | body | 0.954 | 0.950 | 0.009 | //core:core |
| kotlin | elide_incremental | private_member | 1.114 | 1.131 | 0.088 | //core:core |
| kotlin | elide_incremental | internal_module_api | 3.443 | 3.332 | 0.281 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide_incremental | public_module_api | 2.147 | 2.151 | 0.027 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | elide_incremental | multi_file_body | 0.986 | 0.990 | 0.034 | //core:core |
| kotlin | elide_fused | clean | 20.277 | 20.030 | 0.475 | //app:app, //app:verify, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade, //protocol:deps_proto, //protocol:worker_protocol_proto, //spare:spare, @@protobuf+//java/core:core, @@protobuf+//java/core:lite_runtime_only |
| kotlin | elide_fused | no_op | 0.241 | 0.246 | 0.010 | none |
| kotlin | elide_fused | comment | 1.139 | 1.125 | 0.067 | //core:core |
| kotlin | elide_fused | body | 1.166 | 1.185 | 0.036 | //core:core |
| kotlin | elide_fused | private_member | 1.260 | 1.237 | 0.059 | //core:core |
| kotlin | elide_fused | internal_module_api | 2.162 | 2.114 | 0.096 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide_fused | public_module_api | 1.039 | 1.030 | 0.022 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | elide_fused | multi_file_body | 1.238 | 1.265 | 0.055 | //core:core |
| kotlin | elide_fused_pruned | clean | 20.710 | 20.769 | 0.272 | //app:app, //app:verify, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade, //protocol:deps_proto, //protocol:worker_protocol_proto, //spare:spare, @@protobuf+//java/core:core, @@protobuf+//java/core:lite_runtime_only |
| kotlin | elide_fused_pruned | no_op | 0.237 | 0.232 | 0.021 | none |
| kotlin | elide_fused_pruned | comment | 1.155 | 1.152 | 0.023 | //core:core |
| kotlin | elide_fused_pruned | body | 1.291 | 1.307 | 0.045 | //core:core |
| kotlin | elide_fused_pruned | private_member | 1.313 | 1.327 | 0.030 | //core:core |
| kotlin | elide_fused_pruned | internal_module_api | 1.546 | 1.546 | 0.020 | //core:core, //facade:facade |
| kotlin | elide_fused_pruned | public_module_api | 0.902 | 0.904 | 0.028 | //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | elide_fused_pruned | multi_file_body | 1.236 | 1.236 | 0.031 | //core:core |

## Trace metrics

Memory values are maximum complete bucket averages across measured samples, not process peak RSS.
Bazel memory is heap plus non-heap; worker memory excludes non-worker actions. Missing counters are n/a.

| Language | Mode | Edit | Mean critical-path span (s) | Worker memory (MiB) | Bazel heap + non-heap (MiB) |
| --- | --- | --- | ---: | ---: | ---: |
| kotlin | vanilla | clean | 27.542 | 1335.7 | 380.4 |
| kotlin | vanilla | no_op | 0.001 | n/a | n/a |
| kotlin | vanilla | comment | 2.852 | 1344.0 | 322.9 |
| kotlin | vanilla | body | 2.106 | 1603.7 | 372.4 |
| kotlin | vanilla | private_member | 1.881 | 1725.2 | 367.4 |
| kotlin | vanilla | internal_module_api | 1.569 | 1873.4 | 336.4 |
| kotlin | vanilla | public_module_api | 0.641 | n/a | n/a |
| kotlin | vanilla | multi_file_body | 1.495 | 1495.2 | 356.4 |
| kotlin | vanilla_abi | clean | 27.760 | 1185.9 | 328.9 |
| kotlin | vanilla_abi | no_op | 0.001 | n/a | n/a |
| kotlin | vanilla_abi | comment | 1.856 | 1149.6 | 391.0 |
| kotlin | vanilla_abi | body | 1.274 | 1240.9 | 377.6 |
| kotlin | vanilla_abi | private_member | 1.429 | 1208.9 | 344.0 |
| kotlin | vanilla_abi | internal_module_api | 2.268 | 1460.8 | 400.4 |
| kotlin | vanilla_abi | public_module_api | 0.841 | 1348.2 | 319.1 |
| kotlin | vanilla_abi | multi_file_body | 0.955 | 1404.7 | 378.0 |
| kotlin | elide | clean | 17.500 | 1027.7 | 371.9 |
| kotlin | elide | no_op | 0.001 | n/a | n/a |
| kotlin | elide | comment | 1.673 | 839.0 | 460.0 |
| kotlin | elide | body | 1.866 | 865.1 | 573.0 |
| kotlin | elide | private_member | 1.787 | 834.2 | 486.0 |
| kotlin | elide | internal_module_api | 1.888 | 883.7 | 611.0 |
| kotlin | elide | public_module_api | 0.777 | n/a | n/a |
| kotlin | elide | multi_file_body | 1.995 | 853.4 | 492.3 |
| kotlin | elide_abi | clean | 18.103 | 1402.4 | 339.2 |
| kotlin | elide_abi | no_op | 0.001 | n/a | n/a |
| kotlin | elide_abi | comment | 0.933 | 1223.8 | 506.4 |
| kotlin | elide_abi | body | 1.051 | 1186.0 | 515.7 |
| kotlin | elide_abi | private_member | 1.074 | 1178.9 | 491.7 |
| kotlin | elide_abi | internal_module_api | 2.120 | 1175.6 | 467.1 |
| kotlin | elide_abi | public_module_api | 0.924 | 1123.2 | 370.1 |
| kotlin | elide_abi | multi_file_body | 1.071 | 1197.3 | 391.7 |
| kotlin | elide_pruned | clean | 17.880 | 1484.5 | 343.9 |
| kotlin | elide_pruned | no_op | 0.001 | n/a | n/a |
| kotlin | elide_pruned | comment | 0.997 | 1207.0 | 382.3 |
| kotlin | elide_pruned | body | 1.058 | 1168.5 | 453.1 |
| kotlin | elide_pruned | private_member | 1.166 | 1191.0 | 396.2 |
| kotlin | elide_pruned | internal_module_api | 1.439 | 1170.4 | 349.7 |
| kotlin | elide_pruned | public_module_api | 0.758 | n/a | n/a |
| kotlin | elide_pruned | multi_file_body | 1.173 | 1159.3 | 466.9 |
| kotlin | elide_incremental | clean | 28.398 | 2598.3 | 331.3 |
| kotlin | elide_incremental | no_op | 0.001 | n/a | n/a |
| kotlin | elide_incremental | comment | 0.748 | n/a | n/a |
| kotlin | elide_incremental | body | 0.776 | n/a | n/a |
| kotlin | elide_incremental | private_member | 0.928 | 2673.8 | 347.8 |
| kotlin | elide_incremental | internal_module_api | 3.214 | 2922.1 | 430.7 |
| kotlin | elide_incremental | public_module_api | 1.941 | 3008.9 | 454.8 |
| kotlin | elide_incremental | multi_file_body | 0.811 | n/a | n/a |
| kotlin | elide_fused | clean | 17.000 | 1070.2 | 341.0 |
| kotlin | elide_fused | no_op | 0.001 | n/a | n/a |
| kotlin | elide_fused | comment | 0.949 | 859.1 | 421.6 |
| kotlin | elide_fused | body | 0.988 | 863.8 | 427.0 |
| kotlin | elide_fused | private_member | 1.075 | 872.8 | 450.6 |
| kotlin | elide_fused | internal_module_api | 1.965 | 866.3 | 435.2 |
| kotlin | elide_fused | public_module_api | 0.846 | n/a | n/a |
| kotlin | elide_fused | multi_file_body | 1.067 | 870.5 | 459.6 |
| kotlin | elide_fused_pruned | clean | 17.540 | 1224.1 | 316.4 |
| kotlin | elide_fused_pruned | no_op | 0.001 | n/a | n/a |
| kotlin | elide_fused_pruned | comment | 0.973 | 861.2 | 612.6 |
| kotlin | elide_fused_pruned | body | 1.113 | 859.9 | 485.4 |
| kotlin | elide_fused_pruned | private_member | 1.126 | 860.9 | 541.6 |
| kotlin | elide_fused_pruned | internal_module_api | 1.369 | 935.8 | 594.0 |
| kotlin | elide_fused_pruned | public_module_api | 0.710 | n/a | n/a |
| kotlin | elide_fused_pruned | multi_file_body | 1.068 | 855.7 | 578.0 |
