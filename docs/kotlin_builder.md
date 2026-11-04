# rules_kotlin KotlinBuilder shim

`rules_elide` ships a drop-in `KotlinBuilder` shim that lets you speed up
existing `kt_jvm_library` / `kt_jvm_binary` / `kt_jvm_test` targets without
migrating any BUILD files. You swap the `rules_kotlin` toolchain for an
Elide-backed one; every `kt_jvm_*` rule in that toolchain's scope compiles
through Elide with no other changes required.

## How it works

`rules_kotlin` drives compilation through a pluggable `kotlinbuilder` field on
its toolchain. `rules_elide` provides:

1. **`elide_kotlin_builder`** — a persistent-worker shim that implements the
   `KotlinBuilder` RPC contract expected by `rules_kotlin`. On each
   `KotlinCompile` action it routes compilation, supported KAPT requests, and
   KSP2 processing through Elide. Specialized processor requests retain the
   stock `rules_kotlin` worker fallback described below.
2. **`register_elide_kotlin_toolchain`** — a Starlark macro in
   `@rules_elide//elide/kotlin:toolchain.bzl` that wires the shim into a
   standard `kt_toolchain`. It wraps `define_kt_toolchain` from `rules_kotlin`,
   re-emits the resulting `ToolchainInfo` with `kotlinbuilder` overridden to a
   config-injecting launcher, and declares the resulting target as a
   `kt_toolchain_type` toolchain.

## Usage

### Step 1 — declare the toolchain in a BUILD file

```python
load("@rules_elide//elide/kotlin:toolchain.bzl", "register_elide_kotlin_toolchain")

register_elide_kotlin_toolchain(
    name = "elide_kt",
    elide = "@elide_linux_amd64//:bin/elide",   # platform-specific — see caveats
    fallback_builder = "@rules_kotlin//src/main/kotlin:build",
    language_version = "2.4",
    api_version = "2.4",
)
```

`**kwargs` (e.g. `language_version`, `api_version`, `jvm_target`) are forwarded
to `define_kt_toolchain` unchanged, so you can tune the underlying toolchain
exactly as you would a plain `rules_kotlin` one.

The macro creates these targets from one `name`:

| Target | Purpose |
|---|---|
| `<name>` | The registered `toolchain()` — this is what you pass to `register_toolchains` |
| `<name>_impl` | The wrapping impl rule that swaps `kotlinbuilder` |
| `<name>_launcher` | The POSIX launcher that resolves runfiles and execs the shim |
| `<name>_ksp2_launcher` | Native-mode launcher for the separate KSP2 worker |
| `<name>_base` / `<name>_base_impl` | The stock `kt_toolchain` materialized by `define_kt_toolchain`; only `_base_impl` is consumed internally |

### Step 2 — register in MODULE.bazel

The macro cannot self-register because `native.register_toolchains` is not
callable from a BUILD-loaded macro. Add the registration to your module root:

```python
# MODULE.bazel
register_toolchains("//:elide_kt")
```

Root-module registrations are resolved before transitive dependencies, so this
wins over `rules_kotlin`'s default toolchain registration automatically.

### Full MODULE.bazel example

```python
module(name = "my_module")

bazel_dep(name = "rules_elide", version = "0.0.0")
bazel_dep(name = "rules_kotlin", version = "2.4.21")

elide = use_extension("@rules_elide//elide:extensions.bzl", "elide")
elide.install(channel = "nightly")
use_repo(elide, "elide_linux_amd64", "elide_toolchains")

# Base Elide toolchain (for elide_java_library etc.)
register_toolchains("@elide_toolchains//:all")

# Elide-backed Kotlin toolchain (replaces rules_kotlin default for kt_jvm_*)
register_toolchains("//:elide_kt")
```

No BUILD file changes to existing `kt_jvm_library` targets are needed.

## Routing and fallback

The shim compiles plain Kotlin and mixed Kotlin/Java targets through Elide.
In native mode, supported KAPT and KSP2 requests also use Elide. Specialized
processor options retain the stock worker fallback; legacy mode delegates all
processing to the stock workers. Routing is automatic from the request payload.

## Native compiler and processor APIs

`register_elide_kotlin_toolchain` defaults to `native_tools = True`, requiring
Elide 1.6.2 or later. Use `native_tools = False` for older pinned distributions;
that retains the ABI plugin, translated dependency reports, and stock processor
workers. Set `language_version` and `api_version` to versions supported by the
embedded compiler (the 1.6.2 smoke fixture uses `2.4`; the stock rules_kotlin
`2.1` default is too old for that compiler).

With `experimental_use_abi_jars = True`, native mode emits the full jar and ABI
jar with `kotlinc -- --emit-abi <jar>`. There is no filesystem search for
`jvm-abi-gen.jar`. These outputs belong to the same action; use the native
`elide_kotlin_*` ABI compile-avoidance setting when separate header actions are
needed to start downstream compilation early.

Native mode asks Elide for `--jdeps` directly and preserves its dependency
classification and any extended fields. The shim checks explicit references
against `--direct_dependencies` when `strict_kotlin_deps` is `warn` or `error`.
The older `--report-used-deps` translation remains available in legacy mode.

KAPT requests map generated source, class, and stub jars to `--kapt-sources`,
`--kapt-classes`, and `--kapt-stubs`. Processor paths, names, and `-A` options
are forwarded. Requests with custom stub plugins or other javac options retain
the stock fallback rather than silently dropping those settings.

The wrapper also replaces the separate rules_kotlin KSP2 worker in native mode.
It forwards generated source/class jars, processor dependencies and options,
module name, JVM target, language/API versions, and source jars. Requests for
the stock worker's experimental PSI-resolution mode use the stock KSP2 worker.
Old KSP compiler-plugin requests continue to use the KotlinBuilder fallback.
Processor failures are reported as build failures, not retried using another
processor implementation.

## Caveats

**`rules_elide` now depends on `rules_kotlin`.**
`elide/kotlin/toolchain.bzl` loads `define_kt_toolchain` from
`@rules_kotlin//kotlin:core.bzl`. The `rules_kotlin` module must therefore
appear as a `bazel_dep` in any module that loads this file, even if no
`kt_jvm_*` rules are used directly.

**The `elide` binary label is platform-specific.**
Each platform variant is exposed as `@elide_<os>_<cpu>//:bin/elide` by the
`elide` module extension. There is no host-agnostic alias yet. To support
multiple execution platforms, use a `select()`:

```python
register_elide_kotlin_toolchain(
    name = "elide_kt",
    elide = select({
        "@platforms//os:linux": "@elide_linux_amd64//:bin/elide",
        "@platforms//os:macos": "@elide_macos_arm64//:bin/elide",
    }),
    fallback_builder = "@rules_kotlin//src/main/kotlin:build",
    language_version = "2.4",
    api_version = "2.4",
)
```

**JAVA_HOME is derived from the registered JDK.**
The launcher script derives `JAVA_HOME` at runtime from the `bin/java`
rlocation inside the Bazel-registered JDK. Unusual JDK layouts (a JRE without
a `bin/java`, or a JDK whose `java` binary lives at an unexpected relative path)
may require revisiting the launcher logic in
`elide/kotlin/toolchain.bzl`.

**ToolchainInfo field list is pinned to rules_kotlin 2.4.21.**
The `_elide_kt_toolchain` rule in `elide/kotlin/toolchain.bzl` enumerates the
fields of `rules_kotlin`'s internal `ToolchainInfo` in order to copy them and
override `kotlinbuilder`. This list must be re-validated whenever `rules_kotlin`
is upgraded across a major version; a field added upstream would be silently
dropped from the re-emitted `ToolchainInfo`, which would cause runtime failures.

**Windows is not supported.**
The launcher script is POSIX `bash`. Windows workers are not currently
supported.

## Reference

Load path: `@rules_elide//elide/kotlin:toolchain.bzl`

```
register_elide_kotlin_toolchain(name, elide, fallback_builder, native_tools = True, **kwargs)
```

| Argument | Type | Description |
|---|---|---|
| `name` | string | Base name for the generated targets (see target table above). |
| `elide` | label | The `elide` binary, resolved via runfiles rlocation and passed as `--elide` to the shim. |
| `fallback_builder` | label | Stock `rules_kotlin` KotlinBuilder, passed as `--fallback_builder` to the shim (e.g. `@rules_kotlin//src/main/kotlin:build`). |
| `native_tools` | `True` | Elide 1.6.2+ native ABI, jdeps, KAPT, and KSP2; False retains legacy behavior. |
| `**kwargs` | — | Forwarded to `define_kt_toolchain` (`language_version`, `api_version`, `jvm_target`, `experimental_use_abi_jars`, etc.). |

The e2e workspace at `e2e/kotlin_builder/` exercises the macro, the plain
compile and ABI path (`//:greeter`), native KAPT (`//:annotated`), native
KSP2 (`//:symbols`), and standalone processor rules. See its README for
commands and output verification.
