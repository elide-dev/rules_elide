# PGO profile collection

Collects Native Image PGO profiles for the Elide `kotlinc` compile paths, to feed
a `--pgo` rebuild of the Elide image on the Elide side.

`collect.sh` drives a **PGO-instrumented** elide binary over the 50-file,
self-contained `benchmarks/sources/kotlin/sample` workload (package `sample`,
kotlin-stdlib only — no classpath needed). Each case runs in its own clean CWD
and the flushed `default.iprof` is collected to `profiles/<case>.iprof`. Set
`ELIDE_PROFILES=<dir>` to also copy each profile there as
`kotlinc-<case>.iprof` (e.g. an Elide checkout's `tools/profiles`, the input
for a `--pgo` rebuild).

```bash
ELIDE=/abs/path/to/instrumented/elide benchmarks/pgo/collect.sh           # all cases
ELIDE=... benchmarks/pgo/collect.sh worker                                # one case
ELIDE_PROFILES=/path/to/tools/profiles ELIDE=... benchmarks/pgo/collect.sh  # + copy
```

## Cases

| case          | invocation                                            | hot path profiled |
|---------------|-------------------------------------------------------|-------------------|
| `oneshot`     | `elide kotlinc -- -d <out> <srcs>`                    | cold single compile |
| `jvmabigen`   | full compile + jvm-abi-gen plugin (ABI jar side-out)  | ABI-jar codegen |
| `karbine`     | `elide kotlinc --abi-only -- …`                       | header-only (WHIPLASH#1111) |
| `worker`      | N WorkRequests → `kotlinc --persistent_worker`        | warm request loop |
| `workercache` | *pending* — in-worker classpath cache (WHIPLASH#1107) | warm + cache hits |

## Key facts

- **`--safe-close` (top-level) is always passed** — it is what flushes
  `default.iprof` on clean shutdown, in *every* mode (verified empirically; a
  plain one-shot exit does **not** flush without it).
- The `worker` case uses `gen_workrequest.py` to hand-encode length-delimited
  Bazel `WorkRequest`s (string `arguments` only; no protobuf dependency) and
  sends `WARM_ROUNDS` (default 3) module compiles so the worker loop runs warm.
  This is the same forwarded-request shape rules_elide's `ElideWorker` produces.
- Profile capture and the final `--pgo` build must use elide binaries from the
  **same source revision** (Native Image drops profile entries for changed
  methods).

`profiles/` is gitignored (each `.iprof` is ~50 MB).

## Captured worker cases

The cases above are hand-built and small. `capture.py` instead records what a
real rules_elide build sends to `elide javac` and `elide kotlinc` workers, and
`replay.py` feeds that back into any Elide binary without Bazel. This is the
training input for large, warm compiles: the workload the resident workers
serve in practice.

```bash
# 1. Capture with a release binary (DIST is the directory holding bin/elide).
benchmarks/pgo/capture.py --elide-dist DIST --output /tmp/cases/java --commons-lang CHECKOUT
benchmarks/pgo/capture.py --elide-dist DIST --output /tmp/cases/kotlin --kotlin-builder

# 2. Train: replay into an instrumented binary and collect the profiles.
python3 /tmp/cases/java/replay.py --elide INSTRUMENTED/bin/elide --profiles PROFILES
```

Captured cases are committed under `cases/` as Git LFS objects, so training
does not need a capture first:

```bash
git lfs pull --include 'benchmarks/pgo/cases/*'
tar --zstd -xf benchmarks/pgo/cases/java.tar.zst -C /tmp
python3 /tmp/java/replay.py --elide INSTRUMENTED/bin/elide --profiles PROFILES
```

| case | rules | workload |
|------|-------|----------|
| `java` | `elide_java_library` | Apache Commons Lang |
| `java-shim` | `java_library` through the `JavaBuilder` shim | Apache Commons Lang |
| `kotlin` | `elide_kotlin_library` | this repository's KotlinBuilder sources |
| `kotlin-shim` | `kt_jvm_library` through the `KotlinBuilder` shim | this repository's KotlinBuilder sources |

Each archive's `manifest.json` records the Elide version, rules_elide commit
and workload revision it was captured from.

Capture runs `incremental_matrix.py` (clean build, then every edit scenario)
with `bin/elide` replaced by `record_proxy.py`. Each case is a directory, also
written as `<output>.tar.zst` (capture needs Python 3.14 for zstd):

| path | contents |
|------|----------|
| `streams/<tool>.bin` | every WorkRequest sent to that tool's workers, in order |
| `cas/<digest>` | each input file version those requests' arguments name |
| `manifest.json` | streams, Elide version, rules_elide commit, workload revision |
| `replay.py`, `gen_workrequest.py` | the replay; needs only Python 3 |

Replay starts one `elide --safe-close <tool> --persistent_worker` process per
stream and sends the requests one at a time, `--loops` times (default 3). Before
each request it restores the exact input versions that request saw, so edits
replay as edits. Any failed compile fails the replay; a profile trained on
compile errors is worse than none. Per-loop wall time is printed, which also
makes replay a Bazel-free measure of warm worker throughput.

- Files from the Elide distribution (the Kotlin standard library, for example)
  are not stored. Their paths are rewritten at replay to the distribution of the
  binary under test.
- A case bakes in the flags rules_elide emitted when it was captured. Recapture
  after changing how compile actions are built.
- Capture fails if any argument still names the capturing machine or an input
  was not captured; `manifest.json` lists them.
- Inputs that no argument names are not stored either. The shims forward every
  builder input (whole JDKs, the stock Kotlin compiler) with each request; the
  compiler cannot reach a file it was never pointed at.
- Add `--modes elide_shim` to capture the `JavaBuilder`/`KotlinBuilder` shims:
  the same workloads built as stock `java_library`/`kt_jvm_library` targets
  through the Elide toolchains. Those cases also hold the `kotlinc` requests
  that compile the shims themselves.
