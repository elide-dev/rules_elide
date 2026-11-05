# Combined Kotlin ABI emission: 2026-11-05

[Hosted run](https://github.com/elide-dev/rules_elide/actions/runs/41939041510)
and [all timing/action samples](data/incremental-fused-2026-11-05.json).
Commit `576a69feff702cae7cdee6bba75d9597c43dbf0b`, Elide 1.6.2, Bazel 9.3.1.
The full run passed 121 cases and 363 measured samples. This table focuses on
Kotlin; Java and all other modes remain in the structured data. The graph has
20 Core files, three clients, four jobs, and three timed rounds after a discarded
warm-up. See [methodology](INCREMENTAL.md).

Times are mean seconds. Compare columns within this run: the previous hosted
run used a different machine session and had a lower no-op floor.

| Edit | Vanilla | Separate ABI | Combined ABI | Separate + pruning | Combined + pruning |
| --- | ---: | ---: | ---: | ---: | ---: |
| no_op | 0.166 | 0.185 | 0.178 | 0.213 | 0.174 |
| comment | 0.700 | 0.438 | 0.402 | 0.519 | 0.427 |
| body | 1.396 | 0.460 | 0.408 | 0.564 | 0.437 |
| private_member | 1.325 | 0.433 | 0.436 | 0.516 | 0.407 |
| internal_module_api | 1.127 | 1.760 | 1.365 | 0.822 | 0.652 |
| public_module_api | 0.834 | 1.349 | 1.170 | 1.451 | 0.988 |
| multi_file_body | 1.022 | 0.474 | 0.395 | 0.560 | 0.486 |
| multi_module_body | 1.058 | 0.738 | 0.624 | 0.787 | 0.663 |
| multi_module_api | 0.957 | 1.773 | 1.368 | 1.549 | 1.296 |
| unused_dependency_api | 0.886 | 1.788 | 1.412 | 0.459 | 0.407 |
| inline_or_constant | 0.951 | 1.815 | 1.394 | 0.869 | 0.643 |

Combined emission preserved the full-compiler target sets of the corresponding
separate-header mode in every sample and removed the separate ABI compiler
actions. Body edits improved by about 11% without pruning and 23% with pruning.
Internal API edits improved by about 22% and 21%, respectively. Private-member
edits without pruning were effectively tied. Public API edits remain slower
than vanilla in several cases, even after removing the duplicate compiler pass.

These are small, synthetic builds with sequential mode ordering and three samples;
they do not establish a universal improvement. Combined emission delays consumers
until full compilation completes. Keep it opt-in, especially on deeper graphs.
The [performance guide](../docs/performance.md) lists eligibility and next steps.
