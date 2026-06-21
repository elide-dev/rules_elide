# Kotlinc PGO profile collection

Collects Native Image PGO profiles for the Elide `kotlinc` compile paths, to feed
a `--pgo` rebuild of the Elide image on the WHIPLASH side.

`collect.sh` drives a **PGO-instrumented** elide binary over the 50-file,
self-contained `benchmarks/sources/kotlin/sample` workload (package `sample`,
kotlin-stdlib only — no classpath needed). Each case runs in its own clean CWD
and the flushed `default.iprof` is collected to `profiles/<case>.iprof`. Set
`WHIPLASH_PROFILES=<dir>` to also copy each profile there as
`kotlinc-<case>.iprof` (e.g. a WHIPLASH checkout's `tools/profiles`, the input
for a `--pgo` rebuild).

```bash
ELIDE=/abs/path/to/instrumented/elide benchmarks/pgo/collect.sh           # all cases
ELIDE=... benchmarks/pgo/collect.sh worker                                # one case
WHIPLASH_PROFILES=/path/to/tools/profiles ELIDE=... benchmarks/pgo/collect.sh  # + copy
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
