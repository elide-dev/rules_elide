# Performance target ledger

The goal is to outperform stock `rules_java` and `rules_kotlin` while preserving
correctness and useful build features. A win in one edit class does not offset a
regression in another. This ledger separates measured results from work still
needed; it is not a claim that every workload is already faster.

| Dimension | Current evidence | Remaining work |
| --- | --- | --- |
| Clean compilation | [Real Java clean rebuilds](COMMONS_LANG_CLEAN_RESULTS.md) favor Elide (3.341 s vs 7.623 s median); [production Kotlin](KOTLIN_BUILDER_RESULTS.md) combined compilation also wins clean (20.030 s vs 30.031 s stock ABI) | Real library/application targets, deeper graphs, and repeated runs on matched hardware |
| Body/private/multi-file edits | Kotlin ABI avoidance reduced rebuild scope; [real Commons Lang results](COMMONS_LANG_CLEAN_RESULTS.md) still favor stock Java for library implementation and multi-file edits | [Production Kotlin](KOTLIN_BUILDER_RESULTS.md) incremental body edits beat stock ABI (0.950 s vs 1.470 s); additional projects and graph depths remain; [Java combined-emission comparison](JAVA_FUSED_RESULTS.md) |
| Internal/public API edits | [Production Kotlin](KOTLIN_BUILDER_RESULTS.md) pruning wins internal API edits, but public API edits still lose to stock defaults | Reduce compiler/worker overhead and test per-target early versus combined headers |
| No-op builds | Small differences sit near the measurement floor | Measure Bazel analysis overhead separately from compiler work |
| Memory and worker startup | Combined emission removes a separate compiler action and worker pool | Optional traces now record sampled worker memory and critical paths; measure true peak RSS and cold/warm startup next |
| Incremental compiler state | Native IC now retains complete class output with its cache; the production Kotlin runtime matrix passes locally and on hosted CI | Hosted timings expose clean/API and memory regressions when IC is enabled everywhere; [hosted selective IC](KOTLIN_WORKER_RESULTS.md) beats stock timing medians on this fixture but uses more sampled worker memory; retain lifecycle checks |
| Remote execution and caching | RBE and cache correctness checks pass, including native IC's cold remote path; JVM compiler inputs omit LLVM, jextract resources, and native-linking static libraries | Measure transfer/cache-hit latency with the smaller input set; execute combined-emission correctness tests remotely |
| Correctness | Header digests, rebuild boundaries, runtime output, constants, inline code, and resource edits have checks | Broader language constructs, processors/plugins, mixed sources, and cache restoration |
| Feature coverage and usability | Native rules, KotlinBuilder adapter, JVM tools, documentation, and Python wiring exist; stock Java consumers now inherit Kotlin stdlib | Per-target ABI selection is available; measure mixed strategies and maintain an explicit compatibility matrix |

Use the [incremental matrix](INCREMENTAL.md), [recorded baseline](INCREMENTAL_RESULTS.md),
and [combined Kotlin comparison](FUSED_ABI_RESULTS.md) for reproducible evidence.
Preserve regressions in reports. Compare modes within the same run, retain raw
samples and compiler action sets, and keep correctness checks independent of
wall-clock performance. Changes should remain opt-in until broader evidence
supports changing defaults.

## Workload priorities

Use real library and application code to guide optimization and default changes.
The [Commons Lang fixture](INCREMENTAL.md#production-java-sources) compiles a real
library with generated consumers. The [KotlinBuilder fixture](INCREMENTAL.md#production-kotlin-sources)
adds a real Kotlin module and protocol dependencies; real application graphs
and additional projects are still needed. Generated graphs isolate invalidation behavior but do not establish
application-wide performance. Very large targets containing trivial generated
classes are stress diagnostics only. Their throughput or memory results must not
drive compiler heap/cache defaults without confirmation on representative code.

Java timing reports predating `java_release=21` used different compiler targets
(Java 25 for Elide 1.6.2, Java 21 for stock). Treat those timings as provisional;
matched-target reruns are required. Rebuild propagation evidence is retained.
