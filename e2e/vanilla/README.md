# e2e/vanilla — no-Elide baseline

The same project as [`e2e/integration`](../integration), target-for-target, but
built with **stock `rules_java` / `rules_kotlin`** — no Elide. It exists purely
as the baseline for the CodSpeed e2e build benchmarks
(`benchmarks/codspeed/test_e2e_bench.py`): the build-speed gain of Elide is the
gap between this workspace's times and `e2e/integration`'s.

Kept as a separate workspace (own output base, only the default Kotlin toolchain
registered) so no Elide toolchain or build state can bleed into the baseline.

Elide-only targets in `e2e/integration` (`native_app`, `format`) have no vanilla
equivalent and are omitted; the benchmarked set is `//:lib //:app //:kt_lib
//:kt_app //:HelloTest`.
