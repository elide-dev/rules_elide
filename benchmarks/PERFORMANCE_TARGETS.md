# Performance target ledger

The goal is to outperform stock `rules_java` and `rules_kotlin` while preserving
correctness and useful build features. A win in one edit class does not offset a
regression in another. This ledger separates measured results from work still
needed; it is not a claim that every workload is already faster.

| Dimension | Current evidence | Remaining work |
| --- | --- | --- |
| Clean compilation | The 50-source coarse benchmark favored Elide for Java and Kotlin | Real library/application targets, deeper graphs, and repeated runs on matched hardware |
| Body/private/multi-file edits | Kotlin ABI avoidance reduced rebuild scope; [real Commons Lang results](COMMONS_LANG_RESULTS.md) still favor stock Java across all measured edits | [Stock Kotlin ABI comparison](KOTLIN_200_RESULTS.md) now measured on generated sources; real projects and graph depths remain; [Java combined-emission comparison](JAVA_FUSED_RESULTS.md) |
| Internal/public API edits | Pruning reduced propagation; several Kotlin API-edit cases still lost to vanilla | Reduce compiler/worker overhead and test per-target early versus combined headers |
| No-op builds | Small differences sit near the measurement floor | Measure Bazel analysis overhead separately from compiler work |
| Memory and worker startup | Combined emission removes a separate compiler action and worker pool | Optional traces now record sampled worker memory and critical paths; measure true peak RSS and cold/warm startup next |
| Incremental compiler state | Opt-in Kotlin IC was slower than ABI-only on the small graph | Larger targets, deleted/renamed files, cache lifetime, and packing cost |
| Remote execution and caching | RBE and cache correctness checks pass; JVM compiler inputs now omit LLVM and native-linking static libraries | Measure transfer/cache-hit latency with the smaller input set; execute combined-emission correctness tests remotely |
| Correctness | Header digests, rebuild boundaries, runtime output, constants, inline code, and resource edits have checks | Broader language constructs, processors/plugins, mixed sources, and cache restoration |
| Feature coverage and usability | Native rules, KotlinBuilder adapter, JVM tools, documentation, and Python wiring exist | Maintain an explicit compatibility matrix; add target-level performance controls |

Use the [incremental matrix](INCREMENTAL.md), [recorded baseline](INCREMENTAL_RESULTS.md),
and [combined Kotlin comparison](FUSED_ABI_RESULTS.md) for reproducible evidence.
Preserve regressions in reports. Compare modes within the same run, retain raw
samples and compiler action sets, and keep correctness checks independent of
wall-clock performance. Changes should remain opt-in until broader evidence
supports changing defaults.

## Workload priorities

Use real library and application code to guide optimization and default changes.
The [Commons Lang fixture](INCREMENTAL.md#production-java-sources) compiles a real
library with generated consumers; a real multi-module Kotlin/application workload
is still needed. Generated graphs isolate invalidation behavior but do not establish
application-wide performance. Very large targets containing trivial generated
classes are stress diagnostics only. Their throughput or memory results must not
drive compiler heap/cache defaults without confirmation on representative code.

Java timing reports predating `java_release=21` used different compiler targets
(Java 25 for Elide 1.6.2, Java 21 for stock). Treat those timings as provisional;
matched-target reruns are required. Rebuild propagation evidence is retained.
