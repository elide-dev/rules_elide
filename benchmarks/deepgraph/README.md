# Deep-graph fixture

A large, deep dependency-graph Bazel workspace for surfacing the **work-avoidance**
behaviors that trivial micro-benchmarks can't — cross-target ABI compile
avoidance, within-target incremental compilation, and critical-path depth — on
the native `elide_kotlin_library` / `elide_java_library` rules.

`gen.py` emits a self-contained workspace (no external deps) into a gitignored
`ws/`. The generator is the committed artifact.

```bash
benchmarks/deepgraph/gen.py --elide /abs/path/to/elide \
    [--layers 16] [--width 32] [--langs kotlin,java]
cd benchmarks/deepgraph/ws && bazelisk build //kotlin/... //java/...
```

## Topology (per language, `//<lang>/...`)

- **`core`** — one module every layer depends on (maximum reverse-dependency
  fan-out). Holds the ABI/IC traps: a Kotlin `inline fun` + `const` / a Java
  `static final` constant, plus generics and a plain body-only-editable function.
- **`mod0..mod{L-1}`** — a chain (`mod_i` deps on `core` + `mod_{i-1}`), so depth
  = `L` (the critical path). Each module has `W` files. Files within a module are
  **independent** (reference only `core`) so within-target IC could recompile
  ~one of `W`; each module's **entry** file additionally references the previous
  module's entry — the cross-target ABI edge a body-vs-signature edit probes.
- **`app`** — the graph sink, deps on `mod_{L-1}`.

Default 16×32 ≈ 545 files/lang, 18 targets/lang.

## Experiments it enables

- **Cross-target ABI avoidance** — edit a method *body* in `core` and rebuild
  `//<lang>/...`. With avoidance, only `core` recompiles; without, the
  reverse-dependency closure cascades.
- **Within-target IC** — edit one file in a module; time the module rebuild with
  `--@rules_elide//config/kotlinc:incremental` off vs on.
- **Critical-path depth** — clean-build wall-clock scales with `L`.

## Findings (elide 1.3.4+d0a074f2d, 16×32)

Clean build: kotlin ~9.3s, java ~1.2s (same topology; kotlinc is the heavy one).

- **Kotlin compile-avoidance is broken**: a `core` *body* edit re-runs **all 18
  kotlin compile actions** (the whole graph), vs **3** for the identical Java
  edit (Java prunes correctly). A signature edit re-runs 36 (full, expected).
  ROOT CAUSE: the Kotlin `compile_jar` is derived with `java_common.run_ijar`,
  which does NOT produce a body-stable ABI for Kotlin bytecode — a method-body
  change alters the ijar, so every dependent (keyed on it) recompiles. Java's
  ijar *is* body-stable. FIX: the embedded jvm-abi-gen produces a byte-identical
  ABI jar across the same body edit (verified) — use it as the Kotlin
  `compile_jar` instead of `run_ijar`. This is the cross-target 10x for graph
  builds.
- **Within-target IC is net-negative — and it's the Elide IC *engine*, not the
  Bazel wiring.** Measured standalone (no Bazel): a 1-file edit in an
  inference-heavy 12-file module with `elide kotlinc --incremental` is **~2x
  slower than a full compile** (~5.1s vs ~2.6s), with EITHER a persistent or a
  wiped `-d` and a persistent cache dir. So IC does full-compile-equivalent work
  plus IC overhead — it does not prune to the changed file. (An earlier apparent
  "617→241ms IC win" was a process/page-cache warming artifact on trivial files,
  not incrementality.) Fix is upstream in Elide's IC engine; rules_elide
  correctly keeps IC opt-in / off-by-default (`//config/kotlinc:incremental`)
  until it beats a full compile. The "persistent worker directory" approach does
  not help (verified: persistent `-d` is still ~2x slower).

These are the candidate **10x** levers: fixing kotlin body-edit pruning (graph
builds) and making IC not re-emit the world (edit loop). See the session notes /
issues for follow-up.
