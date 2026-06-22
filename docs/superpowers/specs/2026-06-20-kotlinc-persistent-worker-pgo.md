# Persistent Elide kotlinc + PGO profiling (rules_elide side)

**Status:** spec / design
**Date:** 2026-06-20
**Tracks:** WHIPLASH#1111 (Karbine ABI), WHIPLASH#1112 (digest IC), WHIPLASH#1107 (resident worker)

## Goal

Make `rules_elide`'s Kotlin builder invoke Elide as a **resident, persistent**
compiler process, and use that to generate a warm-workload PGO profile for the
Elide native image (`tools/profiles/kotlinc.iprof` on the WHIPLASH side). Two
deliverables:

1. **Persistent forwarding** — keep one warm `elide kotlinc --persistent_worker`
   subprocess per builder worker and forward `WorkRequest`s to it, instead of
   spawning `elide` one-shot per compile.
2. **PGO capture** — drive that resident process under a real build so it
   accumulates a representative profile, plus an **offline replay** path that
   reproduces the same warm code paths deterministically outside Bazel.

## Background: where we are today

The builder is a persistent **JVM** worker (`elide/kotlin/builder/Main.kt`,
`Worker.kt`): Bazel spawns it once with `--persistent_worker` and feeds it
length-delimited `WorkRequest`s. For each request `Router.route` picks the Elide
fast path or `Fallback`; the fast path calls `ElideCompile.plan(...)` and runs
the resulting `elide kotlinc -- …` argv as a **one-shot subprocess**
(`ElideCompile.kt`; the `--` separator is the one-shot form — worker mode omits
it).

Consequence: the builder JVM stays warm, but **`elide` itself is cold on every
compile** — full native-image startup, class init, and Kotlin compiler warm-up
are paid per request. This both (a) leaves the warm-compile win from WHIPLASH's
`--persistent_worker` mode unused and (b) means any PGO profile captured today
reflects cold one-shot startup, not the steady-state we want to optimize.

## Part 1 — Persistent Elide forwarding

### Design

Introduce an `ElideWorker` connection that owns a long-lived
`elide kotlinc --persistent_worker` subprocess and speaks Elide's worker
protocol (the same Bazel `WorkerProtocol` proto Elide consumes; see WHIPLASH
`packages/base/.../cli/worker/BazelWorker.kt`):

- **Lifecycle.** One resident Elide process per builder worker instance, started
  lazily on the first fast-path request and reused for the worker's lifetime.
  On builder shutdown (stdin EOF from Bazel), the builder closes the Elide
  process's stdin so it exits cleanly (this matters for PGO flush, Part 2).
- **Request mapping.** `ElideCompile.plan(...)` already produces the kotlinc
  argv. For worker mode, drop the one-shot `--` framing and send those args as a
  `WorkRequest` to the resident process; read the `WorkResponse` (exit code +
  output) and map it back to the Bazel `WorkResponse`. Per-request `inputs`
  (path + digest) SHOULD be forwarded so Elide's digest-driven IC (WHIPLASH#1112)
  engages.
- **Multi-command requests.** A single Bazel request may expand to a kotlinc
  compile **and** an `elide jar`/srcjar command. Only the kotlinc compile is
  forwarded to the resident worker; the `jar` step stays a one-shot subprocess
  (it is cheap and not on the warm-compile critical path).
- **Routing unchanged.** KSP / fallback routing (`Router.kt`) is untouched;
  fallback still shells out to the stock builder.

### Failure handling

- If the resident process dies or fails to start, fall back to the existing
  one-shot `elide kotlinc -- …` path for that request and restart the resident
  process on the next request. A worker must never wedge on a dead pipe.
- A non-zero `WorkResponse` from Elide is a normal compile failure: surface it as
  the Bazel `WorkResponse` exit code, do not recycle the process.

## Part 2 — PGO capture

Elide's native image, when built with `--pgo-instrument`, writes a
`default.iprof` into its **current working directory on clean shutdown**
(WHIPLASH `tools/scripts/regenerate-pgo.sh`; `--safe-close` guarantees the
flush). PGO here is the Native Image (SVM) layer — where the Kotlin compiler
runs — not the Rust entrypoint. There is no dump-path override today, only CWD.

### 2a. In-Bazel capture (representative)

1. Build the instrumented binary on the WHIPLASH side:
   `./builder build --pgo-instrument --no-strip` (unstripped so the profile and
   any symbolized inspection line up).
2. Point the toolchain at it: `elide.use(local_path = "<abs>/.../bin/elide")`
   (see `elide/kotlin/toolchain.bzl`, `extensions.bzl`).
3. **Pin to a single resident Elide process.** Run the build with one builder
   worker instance and no multiplexing
   (`--worker_max_instances=ElideKotlinBuilder=1`,
   `--noexperimental_worker_multiplex`). One resident Elide process ⇒ one
   `default.iprof`, no CWD collision between concurrent instances (there is no
   per-process dump path to disambiguate them).
4. Build the target project so the resident process serves many compiles (the
   warm steady state). Use the larger benchmark project as the workload.
5. **Shut down cleanly** so the profile flushes: `bazel shutdown` closes the
   builder worker's stdin, the builder closes Elide's stdin, Elide exits via the
   clean-close path and writes `default.iprof` to its CWD (the worker's
   execroot). A SIGKILL'd worker writes nothing.
6. Recover `default.iprof` from the execroot and copy it to the WHIPLASH tree as
   `tools/profiles/kotlinc.iprof`, then enable the (currently commented) slot in
   `tools/settings.mts` `pgoProfiles` and rebuild
   `./builder build --release --lto --preinit --pgo`.

The resident process must therefore set its CWD to a known, stable, writable
location for the training run (a profiling-mode flag on the builder, or a
documented `--worker_extra_flag`/env), so step 5's `default.iprof` is findable
and not wiped with a sandbox.

### 2b. Offline replay (deterministic)

Bazel's worker teardown, sandboxing, and single-instance pinning are awkward to
get exactly right. What PGO actually needs is the set of **hot compiler code
paths**, which depends only on the sequence of `WorkRequest`s the resident Elide
process sees — not on whether Bazel or a pipe delivers them. So:

1. **Record.** Add a record mode to the `ElideWorker` connection
   (`ELIDE_WORKER_RECORD=<path>`): tee every length-delimited `WorkRequest`
   forwarded to Elide into a capture file, byte-for-byte, while still serving the
   build normally.
2. Run one real build of the benchmark project with recording on to produce
   `captured-requests.bin`.
3. **Replay** offline into the instrumented binary, in a clean CWD:
   `cd "$(mktemp -d)" && elide kotlinc --persistent_worker --safe-close < captured-requests.bin`
   → exercises the identical warm-worker compile loop (`BazelWorker.run`, warm
   classloader reuse) and emits a single `default.iprof` deterministically — no
   Bazel teardown, no sandbox archaeology, no instance collisions.
4. Copy `default.iprof` to `tools/profiles/kotlinc.iprof` as in 2a.

Replay is the recommended capture path; in-Bazel (2a) is the fidelity check.

## Requirements

- The builder **MUST** keep one warm `elide kotlinc --persistent_worker`
  subprocess per worker instance and forward kotlinc compiles to it.
- It **MUST** fall back to a one-shot `elide` invocation if the resident process
  is unavailable, and recover on the next request.
- It **MUST** close the resident process's stdin on builder shutdown so an
  instrumented Elide flushes its `default.iprof`.
- It **SHOULD** forward per-input digests so Elide's digest-driven IC engages.
- It **SHOULD** offer a record mode that tees forwarded `WorkRequest`s to a file
  for offline PGO replay.
- The profiling run **MUST** use a single resident Elide instance (no multiplex)
  so exactly one `default.iprof` is produced.
- Profile capture and the final `--pgo` build **MUST** use Elide binaries built
  from the same source revision (Native Image silently drops profile entries for
  methods that changed).

## Risks / gotchas

- **Flush-on-shutdown.** Only a clean exit writes the profile. Verify
  `elide kotlinc --persistent_worker --safe-close` flushes on stdin EOF before
  investing in a full training build.
- **CWD collisions.** `default.iprof` is CWD-relative with no override; concurrent
  resident processes would clobber each other. Single-instance only for training.
- **musl/toolchain parity.** The instrumented and final binaries should target
  the same triple/toolchain as the shipped release so the profile transfers.
- **PGO sharp edges (WHIPLASH).** PGO has known interactions in the Elide build
  (PGO+Crema disables loop vectorization; some flags have produced invalid
  profiles). Confirm Native Image accepts `kotlinc.iprof` and reports coverage of
  the kotlinc hot methods.

## Non-goals

- Productionizing a diverse multi-project PGO corpus (this is a single-project
  "does warm-worker PGO help" experiment; generalization is separate).
- Rust-layer (AutoFDO) profiling of the Elide entrypoint — out of scope; the
  compile hot path is in the SVM image.
- Changing `Router`/`Fallback` semantics or the one-shot CLI path.
