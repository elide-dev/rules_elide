# Performance target ledger

The goal is to outperform stock `rules_java` and `rules_kotlin` while preserving
correctness and useful build features. A win in one edit class does not offset a
regression in another. This ledger separates measured results from work still
needed; it is not a claim that every workload is already faster.

| Dimension | Current evidence | Remaining work |
| --- | --- | --- |
| Clean compilation | The 50-source coarse benchmark favored Elide for Java and Kotlin | Larger targets, deeper graphs, and repeated runs on matched hardware |
| Body/private/multi-file edits | Kotlin ABI avoidance substantially reduced rebuild scope; combined emission often reduced latency further | Larger real projects and graph depths; Java combined-emission comparison |
| Internal/public API edits | Pruning reduced propagation; several Kotlin API-edit cases still lost to vanilla | Reduce compiler/worker overhead and test per-target early versus combined headers |
| No-op builds | Small differences sit near the measurement floor | Measure Bazel analysis overhead separately from compiler work |
| Memory and worker startup | Combined emission removes a separate compiler action and worker pool | Measure peak RSS, worker counts, and cold/warm startup; no quantitative win established |
| Incremental compiler state | Opt-in Kotlin IC was slower than ABI-only on the small graph | Larger targets, deleted/renamed files, cache lifetime, and packing cost |
| Remote execution and caching | Existing RBE and cache correctness checks pass | Measure transfer/cache-hit latency; execute combined-emission correctness tests remotely |
| Correctness | Header digests, rebuild boundaries, runtime output, constants, inline code, and resource edits have checks | Broader language constructs, processors/plugins, mixed sources, and cache restoration |
| Feature coverage and usability | Native rules, KotlinBuilder adapter, JVM tools, documentation, and Python wiring exist | Maintain an explicit compatibility matrix; add target-level performance controls |

Use the [incremental matrix](INCREMENTAL.md), [recorded baseline](INCREMENTAL_RESULTS.md),
and [combined Kotlin comparison](FUSED_ABI_RESULTS.md) for reproducible evidence.
Preserve regressions in reports. Compare modes within the same run, retain raw
samples and compiler action sets, and keep correctness checks independent of
wall-clock performance. Changes should remain opt-in until broader evidence
supports changing defaults.
