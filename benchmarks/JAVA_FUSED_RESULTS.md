# Combined Java ABI emission: 2026-11-05

[Hosted run](https://github.com/elide-dev/rules_elide/actions/runs/41942510601)
and [all timing/action samples](data/java-fused-2026-11-05.json).
Commit `1c4d231`; Elide 1.6.2, Bazel 9.3.1, rules_java 9.9.0.
The run passed 66 cases with 330 measured samples. Core has 20 source files,
Facade fans out to three clients, and builds use four jobs. Each case has five
measured rounds after one discarded warm-up. All runtime jars are requested.

This table uses **median seconds**. The stock body-edit samples include a 1.080s
outlier: its mean was 0.462s but its median was 0.311s. Raw samples and means remain
available; using the mean alone would exaggerate the improvement.

| Edit | Stock | Elide default | Separate ABI | Separate + pruning | Combined ABI | Combined + pruning |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| no_op | 0.280 | 0.195 | 0.196 | 0.287 | 0.178 | 0.174 |
| comment | 0.373 | 0.289 | 0.315 | 0.392 | 0.286 | 0.298 |
| body | 0.311 | 0.297 | 0.316 | 0.329 | 0.266 | 0.297 |
| private_member | 0.298 | 0.288 | 0.303 | 0.327 | 0.264 | 0.282 |
| internal_module_api | 0.604 | 0.592 | 0.796 | 0.613 | 0.594 | 0.349 |
| public_module_api | 0.567 | 0.508 | 0.641 | 0.608 | 0.527 | 0.458 |
| multi_file_body | 0.253 | 0.284 | 0.298 | 0.336 | 0.277 | 0.288 |
| multi_module_body | 0.391 | 0.361 | 0.397 | 0.440 | 0.359 | 0.361 |
| multi_module_api | 0.582 | 0.593 | 0.745 | 0.732 | 0.620 | 0.538 |
| unused_dependency_api | 0.548 | 0.569 | 0.756 | 0.583 | 0.597 | 0.269 |
| inline_or_constant | 0.630 | 0.580 | 0.742 | 0.648 | 0.596 | 0.347 |

Combined emission preserved corresponding separate-mode full compiler target sets
and removed separate Java ABI actions. Its body-edit median was 0.266s versus
0.316s for separate ABI emission. Adding pruning limited internal API edits to
Core + Facade, with a 0.349s median versus stock's 0.604s and separate-plus-pruning's
0.613s. The action-count reduction is stronger evidence than small timing gaps.

This is not an across-the-board win. Multi-file body edits were slower than stock,
and default Elide was competitive with combined emission in several cases. No-op
medians varied from 0.174s to 0.287s across modes, showing substantial overhead
variation. Modes ran sequentially with a shared Bazel server; newer benchmark
versions isolate servers and workers between modes. Repeat on larger, representative
graphs and inspect traces before changing defaults. The optional combined mode also
makes consumers wait for the full compile instead of an early header.
