# Production Kotlin worker and incremental-selection comparison

[Hosted run 41960543640](https://github.com/elide-dev/rules_elide/actions/runs/41960543640)
completed at commit `5e53353e49929c97fbb7b4a01257274129b8afac` with 48 cases
and 144 measured samples. All runtime and rebuild-boundary checks passed.
[Raw samples](data/kotlin-worker-modes-2026-11-05.json) retain action sets and trace
metrics. This run includes the JDK-only IC adapter and per-target IC selection;
it predates the classpath-state preservation change in `b1d08e5`.

Selective IC beats both stock modes by median in every measured timing scenario
on this fixture. It keeps IC on the production Core module and uses combined
headers with pruning elsewhere. This is a timing result for one production
module and generated consumers, not evidence of superiority across projects or
memory usage. Three measured rounds per case do not establish statistical
significance, particularly for small no-op and public-API differences.

## Median build time (seconds)

| Mode | Clean | No-op | Comment | Body | Private | Internal API | Public API | Multi-file |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| vanilla | 29.459 | 0.248 | 3.019 | 2.122 | 1.865 | 1.777 | 0.836 | 1.502 |
| vanilla_abi | 29.622 | 0.238 | 1.926 | 1.728 | 1.511 | 2.360 | 1.052 | 1.314 |
| elide_fused_pruned | 19.288 | 0.222 | 1.088 | 1.221 | 1.267 | 1.496 | 0.808 | 1.225 |
| elide_incremental | 23.787 | 0.203 | 0.848 | 0.948 | 0.952 | 3.035 | 2.388 | 1.049 |
| elide_selective | 21.668 | 0.226 | 0.889 | 0.940 | 0.986 | 1.142 | 0.742 | 1.016 |
| elide_parallel | 28.646 | 0.239 | 1.088 | 1.268 | 1.222 | 1.473 | 0.598 | 1.110 |

The four-process `elide_parallel` mode lowers public API edits to 0.598 s, but
clean time rises to 28.646 s versus 19.288 s with the otherwise comparable
`elide_fused_pruned` mode. It also changes stock Java/protobuf worker scheduling
because `--noworker_multiplex` is global. It remains an explicit experiment,
not a recommended default.

Enabling IC everywhere still loses API edits badly: 3.035 s for internal API
and 2.388 s for public API. The classpath-state preservation change targets
unnecessary full resets in that path; it requires a separate hosted comparison.
The JDK-only adapter removes the previous protobuf bootstrap, but cross-run
clean-time differences from the earlier report are not an isolated measurement
of that change.

## Memory and remaining gaps

Maximum complete worker-memory bucket averages for selective IC were 1,917 MiB
on clean builds versus 1,422 MiB for stock ABI mode, and 1,666 MiB on multi-file
edits versus 1,218 MiB. Combined/pruned mode was lower at 1,091 MiB and 842 MiB,
respectively. Four-process compilation reached 2,168 MiB on multi-file edits.
These are sampled bucket averages, not peak RSS. Missing counters for short
builds are unavailable, not zero. Bazel memory and per-case counters remain in
the raw data and full tables below.

No single configuration is proven better on every dimension. Java implementation
edits still lose in the [Commons Lang comparison](COMMONS_LANG_CLEAN_RESULTS.md).
Remote latency, true peak RSS, more projects, and repeatability remain open.

## Reproduction and scope

```sh
python3 benchmarks/incremental_matrix.py --kotlin-builder --languages kotlin \
  --profiles --rounds 3 --modes vanilla vanilla_abi elide_fused_pruned \
  elide_incremental elide_selective elide_parallel
```

The fixture contains nine production KotlinBuilder files and two protocol files,
with source SHA-256 `71682b146d0a77af9b5159021a8d4ad3f743ce9768ba48a41d9ccb666dc41884`.
Both toolchains target JVM 21. Versions are Bazel 9.3.1, rules_java 9.9.0,
rules_kotlin 2.4.21, and Elide 1.6.2. The hosted runner has four CPUs and uses four
Bazel jobs. Each case discards one warm-up and measures three rounds. Clean
builds follow untimed Bazel clean, include tool/protocol bootstrap, and retain
warm downloads. Shared action caches and remote execution are disabled.

## Complete measurements

### Incremental dependency-graph benchmark

Commit: `5e53353e49929c97fbb7b4a01257274129b8afac`

Production sources: rules_elide KotlinBuilder at `5e53353e49929c97fbb7b4a01257274129b8afac`; 11 source files.
Source SHA-256: `71682b146d0a77af9b5159021a8d4ad3f743ce9768ba48a41d9ccb666dc41884`; checkout dirty: `False`.
The downstream consumer graph is generated. Runtime assertions run outside build timing.

Times include Bazel invocation, analysis, compilation, and execution-log overhead.
Shared action caches and remote execution are disabled. Every edit starts from a rebuilt pristine graph.
Warm-ups are discarded. Counts include full source compiler actions only; ABI/header actions are reported separately.

| Language | Mode | Edit | Mean (s) | Median (s) | Stddev (s) | Full compile targets per sample |
| --- | --- | --- | ---: | ---: | ---: | --- |
| kotlin | vanilla | clean | 29.349 | 29.459 | 0.382 | //app:app, //app:verify, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade, //protocol:deps_proto, //protocol:worker_protocol_proto, //spare:spare, @@protobuf+//java/core:core, @@protobuf+//java/core:lite_runtime_only, @@rules_kotlin+//src/main/kotlin:build, @@rules_kotlin+//src/main/kotlin:jdeps_merger |
| kotlin | vanilla | no_op | 0.238 | 0.248 | 0.032 | none |
| kotlin | vanilla | comment | 3.165 | 3.019 | 0.398 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla | body | 2.105 | 2.122 | 0.069 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla | private_member | 1.945 | 1.865 | 0.140 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla | internal_module_api | 1.751 | 1.777 | 0.175 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla | public_module_api | 0.821 | 0.836 | 0.047 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | vanilla | multi_file_body | 1.503 | 1.502 | 0.012 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla_abi | clean | 29.680 | 29.622 | 0.266 | //app:app, //app:verify, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade, //protocol:deps_proto, //protocol:worker_protocol_proto, //spare:spare, @@protobuf+//java/core:core, @@protobuf+//java/core:lite_runtime_only, @@rules_kotlin+//src/main/kotlin:build, @@rules_kotlin+//src/main/kotlin:jdeps_merger |
| kotlin | vanilla_abi | no_op | 0.233 | 0.238 | 0.024 | none |
| kotlin | vanilla_abi | comment | 1.934 | 1.926 | 0.165 | //core:core |
| kotlin | vanilla_abi | body | 1.626 | 1.728 | 0.207 | //core:core |
| kotlin | vanilla_abi | private_member | 1.478 | 1.511 | 0.158 | //core:core |
| kotlin | vanilla_abi | internal_module_api | 2.420 | 2.360 | 0.291 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | vanilla_abi | public_module_api | 1.052 | 1.052 | 0.004 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | vanilla_abi | multi_file_body | 1.240 | 1.314 | 0.204 | //core:core |
| kotlin | elide_fused_pruned | clean | 19.561 | 19.288 | 0.492 | //app:app, //app:verify, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade, //protocol:deps_proto, //protocol:worker_protocol_proto, //spare:spare, @@protobuf+//java/core:core, @@protobuf+//java/core:lite_runtime_only |
| kotlin | elide_fused_pruned | no_op | 0.223 | 0.222 | 0.006 | none |
| kotlin | elide_fused_pruned | comment | 1.093 | 1.088 | 0.015 | //core:core |
| kotlin | elide_fused_pruned | body | 1.197 | 1.221 | 0.042 | //core:core |
| kotlin | elide_fused_pruned | private_member | 1.267 | 1.267 | 0.042 | //core:core |
| kotlin | elide_fused_pruned | internal_module_api | 1.486 | 1.496 | 0.028 | //core:core, //facade:facade |
| kotlin | elide_fused_pruned | public_module_api | 0.812 | 0.808 | 0.038 | //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | elide_fused_pruned | multi_file_body | 1.212 | 1.225 | 0.037 | //core:core |
| kotlin | elide_incremental | clean | 23.916 | 23.787 | 0.846 | //app:app, //app:verify, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade, //protocol:deps_proto, //protocol:worker_protocol_proto, //spare:spare, @@protobuf+//java/core:core, @@protobuf+//java/core:lite_runtime_only, @@rules_elide+//elide/private/ic_worker:ic_worker |
| kotlin | elide_incremental | no_op | 0.211 | 0.203 | 0.019 | none |
| kotlin | elide_incremental | comment | 0.863 | 0.848 | 0.027 | //core:core |
| kotlin | elide_incremental | body | 0.939 | 0.948 | 0.059 | //core:core |
| kotlin | elide_incremental | private_member | 0.993 | 0.952 | 0.071 | //core:core |
| kotlin | elide_incremental | internal_module_api | 3.104 | 3.035 | 0.140 | //app:app, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade |
| kotlin | elide_incremental | public_module_api | 2.243 | 2.388 | 0.262 | //app:app, //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | elide_incremental | multi_file_body | 1.035 | 1.049 | 0.067 | //core:core |
| kotlin | elide_selective | clean | 22.006 | 21.668 | 1.102 | //app:app, //app:verify, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade, //protocol:deps_proto, //protocol:worker_protocol_proto, //spare:spare, @@protobuf+//java/core:core, @@protobuf+//java/core:lite_runtime_only, @@rules_elide+//elide/private/ic_worker:ic_worker |
| kotlin | elide_selective | no_op | 0.224 | 0.226 | 0.007 | none |
| kotlin | elide_selective | comment | 0.894 | 0.889 | 0.026 | //core:core |
| kotlin | elide_selective | body | 0.958 | 0.940 | 0.048 | //core:core |
| kotlin | elide_selective | private_member | 0.979 | 0.986 | 0.013 | //core:core |
| kotlin | elide_selective | internal_module_api | 1.166 | 1.142 | 0.078 | //core:core, //facade:facade |
| kotlin | elide_selective | public_module_api | 0.776 | 0.742 | 0.070 | //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | elide_selective | multi_file_body | 1.052 | 1.016 | 0.070 | //core:core |
| kotlin | elide_parallel | clean | 28.191 | 28.646 | 0.930 | //app:app, //app:verify, //clients:client0, //clients:client1, //clients:client2, //core:core, //facade:facade, //protocol:deps_proto, //protocol:worker_protocol_proto, //spare:spare, @@protobuf+//java/core:core, @@protobuf+//java/core:lite_runtime_only |
| kotlin | elide_parallel | no_op | 0.240 | 0.239 | 0.043 | none |
| kotlin | elide_parallel | comment | 1.086 | 1.088 | 0.012 | //core:core |
| kotlin | elide_parallel | body | 1.250 | 1.268 | 0.070 | //core:core |
| kotlin | elide_parallel | private_member | 1.227 | 1.222 | 0.039 | //core:core |
| kotlin | elide_parallel | internal_module_api | 1.483 | 1.473 | 0.029 | //core:core, //facade:facade |
| kotlin | elide_parallel | public_module_api | 0.598 | 0.598 | 0.011 | //clients:client0, //clients:client1, //clients:client2, //facade:facade |
| kotlin | elide_parallel | multi_file_body | 1.108 | 1.110 | 0.028 | //core:core |

### Trace metrics

Memory values are maximum complete bucket averages across measured samples, not process peak RSS.
Bazel memory is heap plus non-heap; worker memory excludes non-worker actions. Missing counters are n/a.

| Language | Mode | Edit | Mean critical-path span (s) | Worker memory (MiB) | Bazel heap + non-heap (MiB) |
| --- | --- | --- | ---: | ---: | ---: |
| kotlin | vanilla | clean | 26.997 | 1381.1 | 288.7 |
| kotlin | vanilla | no_op | 0.001 | n/a | n/a |
| kotlin | vanilla | comment | 2.925 | 1436.7 | 399.9 |
| kotlin | vanilla | body | 1.902 | 1213.9 | 421.2 |
| kotlin | vanilla | private_member | 1.746 | 1294.4 | 357.4 |
| kotlin | vanilla | internal_module_api | 1.581 | 1435.2 | 436.4 |
| kotlin | vanilla | public_module_api | 0.653 | n/a | n/a |
| kotlin | vanilla | multi_file_body | 1.327 | 1713.4 | 433.2 |
| kotlin | vanilla_abi | clean | 27.285 | 1421.9 | 332.8 |
| kotlin | vanilla_abi | no_op | 0.001 | n/a | n/a |
| kotlin | vanilla_abi | comment | 1.714 | 1181.8 | 499.0 |
| kotlin | vanilla_abi | body | 1.414 | 1194.7 | 404.4 |
| kotlin | vanilla_abi | private_member | 1.264 | 1265.8 | 396.0 |
| kotlin | vanilla_abi | internal_module_api | 2.242 | 1442.6 | 463.0 |
| kotlin | vanilla_abi | public_module_api | 0.882 | n/a | n/a |
| kotlin | vanilla_abi | multi_file_body | 1.063 | 1218.5 | 437.0 |
| kotlin | elide_fused_pruned | clean | 16.607 | 1090.6 | 333.0 |
| kotlin | elide_fused_pruned | no_op | 0.001 | n/a | n/a |
| kotlin | elide_fused_pruned | comment | 0.922 | 866.0 | 416.0 |
| kotlin | elide_fused_pruned | body | 1.025 | 848.7 | 391.0 |
| kotlin | elide_fused_pruned | private_member | 1.099 | 878.5 | 345.0 |
| kotlin | elide_fused_pruned | internal_module_api | 1.305 | 871.6 | 371.0 |
| kotlin | elide_fused_pruned | public_module_api | 0.643 | n/a | n/a |
| kotlin | elide_fused_pruned | multi_file_body | 1.055 | 841.9 | 429.4 |
| kotlin | elide_incremental | clean | 20.937 | 2037.2 | 357.0 |
| kotlin | elide_incremental | no_op | 0.001 | n/a | n/a |
| kotlin | elide_incremental | comment | 0.686 | n/a | n/a |
| kotlin | elide_incremental | body | 0.735 | n/a | n/a |
| kotlin | elide_incremental | private_member | 0.818 | n/a | n/a |
| kotlin | elide_incremental | internal_module_api | 2.924 | 2713.8 | 379.2 |
| kotlin | elide_incremental | public_module_api | 2.071 | 2812.1 | 437.3 |
| kotlin | elide_incremental | multi_file_body | 0.857 | 2901.7 | 294.0 |
| kotlin | elide_selective | clean | 19.022 | 1917.3 | 371.8 |
| kotlin | elide_selective | no_op | 0.001 | n/a | n/a |
| kotlin | elide_selective | comment | 0.721 | n/a | n/a |
| kotlin | elide_selective | body | 0.783 | n/a | n/a |
| kotlin | elide_selective | private_member | 0.810 | n/a | n/a |
| kotlin | elide_selective | internal_module_api | 0.998 | 1679.4 | 353.6 |
| kotlin | elide_selective | public_module_api | 0.607 | n/a | n/a |
| kotlin | elide_selective | multi_file_body | 0.878 | 1665.9 | 348.8 |
| kotlin | elide_parallel | clean | 25.273 | 1560.5 | 333.0 |
| kotlin | elide_parallel | no_op | 0.001 | n/a | n/a |
| kotlin | elide_parallel | comment | 0.912 | 1446.4 | 482.0 |
| kotlin | elide_parallel | body | 1.089 | 1440.0 | 442.0 |
| kotlin | elide_parallel | private_member | 1.062 | 1469.1 | 471.2 |
| kotlin | elide_parallel | internal_module_api | 1.310 | 1491.7 | 405.0 |
| kotlin | elide_parallel | public_module_api | 0.436 | n/a | n/a |
| kotlin | elide_parallel | multi_file_body | 0.943 | 2168.0 | 375.4 |
