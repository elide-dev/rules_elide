# ABI compile-avoidance soundness harness

Empirical verification for Karbine ABI compile-avoidance (`elide kotlinc
--abi-only`), the capability behind **rules issue #11** and the
`//config/kotlinc:abi_compile_avoidance` build setting.

When that setting is on, `elide_kotlin_*` derives a Kotlin or mixed Kotlin/Java target's
`JavaInfo.compile_jar` from a dedicated `elide kotlinc --abi-only` **header**
action instead of `java_common.run_ijar`. Bazel keys dependents on that header's
digest, so the behavior is only correct if the header digest is a faithful
function of the *public ABI*. `run.sh` asserts both directions:

| Edit | Header must | Why |
| --- | --- | --- |
| method **body** | stay identical | callers don't observe it → prune dependents (the win) |
| `const val` value | **change** | constant is inlined into callers → they must rebuild |
| `inline fun` body | **change** | inlined into callers → they must rebuild |
| signature | **change** | ABI change → callers must rebuild |
| default-arg value | stay identical | lives in the `$default` bridge, not callers → body-level |

It also pins the two `--abi-only` behaviors the rule wiring depends on: it
accepts a `-d <jar>` output, and on **mixed kt+java** it emits **both Kotlin and Java ABI**.

## Run

```sh
ELIDE=/abs/path/to/elide ./run.sh      # or: ./run.sh /abs/path/to/elide
```

Exits non-zero if any assertion fails. Like `../ic_correctness`, this needs a
real `elide` binary, so it runs locally / on main-push CI rather than on PRs.

The harness also checks Java `javac --abi-only --jar`: body edits preserve the
header, constant/signature edits change it, and downstream javac accepts it.
Use Elide 1.6.2 or later for the complete harness.

Set `ABI_MODE=fused` to exercise the same Kotlin digest assertions through
`--emit-abi` alongside full compilation. Mixed-source and Java checks still use
separate headers. For actual Bazel action-cache and runtime checks in both worker
modes, run `python3 ../integration/verify_fused_abi.py`; this is included in
`tools/verify_integrations.sh jvm` on main CI.
