![rules_elide — Elide for Bazel, with the Elide and Bazel logos](docs/assets/rules_elide-readme-banner.png)

# rules_elide

[![CI](https://github.com/elide-dev/rules_elide/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/elide-dev/rules_elide/actions/workflows/ci.yml)
[![Security checks](https://github.com/elide-dev/rules_elide/actions/workflows/security.yml/badge.svg?branch=main)](https://github.com/elide-dev/rules_elide/actions/workflows/security.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

[Quick start](#quick-start) · [Examples](docs/examples.md) · [Python](docs/python.md) ·
[Kotlin adapter](docs/kotlin_builder.md) · [Testing](docs/testing.md) · [Contributing](CONTRIBUTING.md)

Bazel rules for [Elide](https://elide.dev) — Kotlin / Java compilation, JUnit
Platform tests, documentation and JVM tooling, native KAPT/KSP, and Python
runtime integration powered by Elide. Native-image rules are also available
with the integration limitations described below.

> **Status: evolving API.** Pin a release or specific commit and review the
> [compatibility and coverage limits](docs/testing.md) before upgrading.

## Choose your integration

| What you want to do | Start here |
| --- | --- |
| Compile Java/Kotlin directly with Elide | `elide_java_*` / `elide_kotlin_*` rules and the quick start below |
| Keep existing `kt_jvm_*` targets | [KotlinBuilder adapter](docs/kotlin_builder.md), including native ABI, KAPT, and KSP2 |
| Run ordinary `py_binary` / `py_test` targets on Elide | [Python runtime adapter](docs/python.md); optional matching overlay |
| Generate docs, archives, reports, or C bindings | [JVM tools](#jvm-documentation-and-tooling) and [worked examples](docs/examples.md) |

Bazel 8+ and Bzlmod are required. Elide distributions are pinned by version and
integrity. Current integration coverage is described in [the test map](docs/testing.md),
including the limits for native-image, Python packages, and execution platforms.

## Quick start

To try the checked-out rules immediately:

```sh
(cd e2e/integration && bazel run :app)
```

This README follows `main`; features introduced since the latest release may
require a checkout override until the next release is published.

Replace the `0.0.0` placeholder with your selected release version. To try a local
checkout, add `local_path_override(module_name = "rules_elide", path = "/path/to/rules_elide")`.
The checked-in [sample workspaces](docs/examples.md) already use a local override.

`MODULE.bazel`:

```starlark
bazel_dep(name = "rules_elide", version = "0.0.0")

elide = use_extension("@rules_elide//elide:extensions.bzl", "elide")
elide.install(version = "1.6.2")
use_repo(elide, "elide_toolchains")
register_toolchains("@elide_toolchains//:all")
```

`BUILD.bazel`:

```starlark
load("@rules_elide//elide:defs.bzl", "elide_kotlin_binary", "elide_kotlin_library")

elide_kotlin_library(
    name = "lib",
    srcs = glob(["src/main/kotlin/**/*.kt"]),
)

elide_kotlin_binary(
    name = "app",
    srcs = ["Main.kt"],
    main_class = "MainKt",
    deps = [":lib"],
)
```

```bash
bazel run //:app
```

## Rules reference

| Rule                  | Purpose                                                           | Reference |
|-----------------------|-------------------------------------------------------------------|-----------|
| `elide_java_library`  | Compile `.java` sources into a JavaInfo-bearing jar (via `elide javac --jar`) | [docs/java.md](docs/java.md) |
| `elide_java_binary`   | `_library` + launcher (`elide java`)                              | [docs/java.md](docs/java.md) |
| `elide_java_test`     | `_library` + JUnit Platform launcher                              | [docs/java.md](docs/java.md) |
| `elide_kotlin_library`| Compile mixed `.kt` / `.java` sources (via `elide kotlinc`)       | [docs/kotlin.md](docs/kotlin.md) |
| `elide_kotlin_binary` | `_library` + launcher                                             | [docs/kotlin.md](docs/kotlin.md) |
| `elide_kotlin_test`   | `_library` + JUnit Platform launcher                              | [docs/kotlin.md](docs/kotlin.md) |
| `elide_native_image`  | Native AOT binary from JavaInfo deps (via `elide native-image`)   | [docs/native_image.md](docs/native_image.md) |
| `elide_cc_binary`     | Hermetic C executable built with Elide's bundled clang/lld/sysroot (Linux) | [docs/c.md](docs/c.md) |
| `elide_format`        | In-place format `.java` (google-java-format) or `.kt` (ktfmt)     | [docs/format.md](docs/format.md) |
| `register_elide_python_toolchain` | Opt-in Python 3.13 runtime for ordinary rules_python targets | [docs/python.md](docs/python.md) |
| `elide_toolchain`     | Wrap an elide binary as a Bazel toolchain                         | [docs/toolchain.md](docs/toolchain.md) |
| `register_elide_kotlin_toolchain` | Drop-in `rules_kotlin` toolchain swap — `kt_jvm_*` targets compile via Elide with no BUILD changes | [docs/kotlin_builder.md](docs/kotlin_builder.md) |

Providers: `ElideToolchainInfo`, `ElideInfo` ([docs/providers.md](docs/providers.md)).
Top-level entry point: [`@rules_elide//elide:defs.bzl`](docs/defs.md).

## Toolchain resolution

The `elide` module extension downloads pinned releases from GitHub:

```
https://github.com/elide-dev/elide/releases/download/{tag}/elide.{os}-{cpu}.{ext}
```

Each artifact is verified against an in-tree SRI integrity table. Stable versions
use `v`-prefixed release tags; dated nightly versions use the version verbatim.
Choose a version recorded in `elide/private/versions.bzl`, or use `elide.use`
with a custom distribution. The `channel` option applies to custom URL templates.

Supported platforms:

| OS    | CPU   | Constraint                                              |
|-------|-------|---------------------------------------------------------|
| Linux | amd64 | `@platforms//os:linux` + `@platforms//cpu:x86_64`       |
| Linux | arm64 | `@platforms//os:linux` + `@platforms//cpu:aarch64`      |
| macOS | arm64 | `@platforms//os:macos` + `@platforms//cpu:aarch64`      |

Windows is published on the CDN but not yet supported by these rules — the
launcher templates are POSIX `sh` only. See `Roadmap` below.

`MODULE.bazel.lock` records the resolved hashes (the extension marks itself
`reproducible = True`).

The default Elide version is **1.6.2**. Pins also include 1.6.0, 1.6.1,
1.6.3, and the 1.6.2 nightlies dated 20261102 and 20261103.

## Python overlays

Enable the matching Python runtime when installing a pinned release:

```starlark
elide.install(version = "1.6.2", python = True)
```

Python overlays are pinned for 1.6.0, 1.6.1, 1.6.2, and the supported 1.6.2
nightlies on all four release platforms. The overlay is verified separately and
extracted after the base archive, replacing its executable and adding Python
resources and the component marker. Missing overlay pins fail during module
resolution. The default installation remains base-only; any module requesting
Python enables it for the selected version.

Custom releases can provide `python_url_template` and a `python_integrity` map
alongside `elide.use(url_template = ..., integrity = ...)`. The overlay map must
cover the same platforms as the base map. For `elide.use(local_path = ...)`,
point at an already-overlaid distribution; the local tree is never modified.

Custom Bazel rules that execute Python should use
`ctx.toolchains["@rules_elide//elide:toolchain_type"].elide_info.python_tool_files`
as action inputs along with the toolchain binary. This set includes Python
resources and `conf/components/python`; JVM compile inputs remain separate.
Use [the Python runtime adapter](docs/python.md) to register this distribution
with `rules_python`. Package resolution remains with `rules_python`.

See [the sandbox smoke fixture](e2e/python_overlay/README.md) for an example.

## Compile-rule outputs (`JavaInfo`)

Every compile rule returns a complete `JavaInfo`:

- `output_jar` — the full class JAR produced by `elide javac --jar` /
  `elide kotlinc -d`.
- `compile_jar` — ABI jar derived via `java_common.run_ijar` for fast
  downstream incremental rebuilds, or a source ABI header when enabled.
- `source_jars` — sources packaged via `java_common.pack_sources`
  (IDE sync / Maven publish friendly).

To enable source ABI compilation with Elide 1.6.2, pass:

```sh
bazel build //... \
  --@rules_elide//config/javac:abi_compile_avoidance=true \
  --@rules_elide//config/kotlinc:abi_compile_avoidance=true
```

These opt-in settings use separate `javac --abi-only` / `kotlinc --abi-only`
actions for compile jars. Runtime jars still contain the full implementation.
Kotlin supports both Kotlin-only and mixed Kotlin/Java sources. Java targets
with compiler plugins, annotation-processing options, or `resource_jars` retain
`ijar` so their compile jars include generated or supplied classes. Both worker
and one-shot compilation are supported. Leave the settings off for older Elide
versions that do not support these ABI options.

Java also supports experimental combined header emission with
`--@rules_elide//config/javac:abi_from_compile=true` alongside Java ABI avoidance.
It declares the full jar and ABI jar as outputs of one compiler action. Processor,
plugin, and `resource_jars` configurations retain their existing `ijar` fallback.

For pure Kotlin targets, experimental
`--@rules_elide//config/kotlinc:abi_from_compile=true` additionally emits the header
from the full compile, saving the separate ABI compiler pass. It requires Kotlin
ABI avoidance and Elide 1.6.2. Mixed sources, resources, plugins/processors, friend
modules, and incremental compilation retain the separate pass. Dependents wait
for full code generation, so compare both modes on your graph before adopting it.
See the [performance guide](docs/performance.md) and
[incremental benchmark modes](benchmarks/INCREMENTAL.md).

## JVM documentation and tooling

Load these rules from `@rules_elide//elide:defs.bzl`:

| Rule | Output |
| --- | --- |
| `elide_javadoc` | HTML directory and optional reproducible `-javadoc.jar`; supports dependency classpaths, doclets, and themes |
| `elide_jar` | Reproducible archive with fixed timestamps, path stripping, and optional manifest/main class |
| `elide_jdeps` | Text dependency report for jars/classes |
| `elide_javap` | Text bytecode/API inspection report for named classes |
| `elide_jextract` | Java bindings `.srcjar` plus a generated-source directory output group |
| `elide_kapt` / `elide_ksp` | Generated `.srcjar`, with class/resource and stub jar output groups |

```starlark
elide_javadoc(name = "api_docs", srcs = glob(["src/**/*.java"]), deps = [":api"])
elide_javap(name = "api_bytecode", deps = [":api"], classes = ["example.Api"], opts = ["-c"])
elide_jextract(name = "bindings", srcs = ["include/api.h"], hdrs = ["include/types.h"], package = "example.nativeapi")
```

See [tool attributes](docs/jvm_tools.md) and [processor attributes](docs/processing.md).
All input headers, processor resources, doclet files, and offline link metadata
must be declared. `jextract` runs on the execution platform; it does not infer a
cross-compilation sysroot. Its FFM bindings require an appropriate JDK (22+).
The `elide` Javadoc theme requires a distribution/doclet classpath containing
`dev.elide.doclet.ElideDoclet`; the published 1.6.2 archive cannot load that
class, so use the default theme with that release.

Processor rules are generation steps: consume their source jars in
`rules_java`/`rules_kotlin` and use `generated_classes` for processor resources.
The native `elide_kotlin_*` rules still take individual source files.
KotlinBuilder also supports native KAPT/KSP directly; see
[builder integration](docs/kotlin_builder.md).

## Compiler dependency metadata

Elide 1.6.2+ native Java/Kotlin rules support:

```sh
bazel build //... \
  --@rules_elide//elide:emit_jdeps=true \
  --@rules_elide//elide:prune_unused_inputs=true \
  --output_groups=+jdeps,+unused_inputs
```

Reports are available through `OutputGroupInfo.jdeps` and `unused_inputs`.
Single-compiler targets also attach their dependency proto to `JavaInfo`;
mixed targets expose separate Java and Kotlin reports rather than an incomplete
combined proto. Header reports populate `compile_jdeps` when available.
Pruning connects Elide's conservative `--unused-inputs` report to Bazel's
`unused_inputs_list`. It stays disabled for processor/plugin and incremental
configurations. Both flags default off for compatibility with older releases.

## JUnit Platform tests

`elide_java_test` and `elide_kotlin_test` launch the JUnit Platform
`ConsoleLauncher`. The launcher honours Bazel's test runner contract:
`TEST_TMPDIR`, `XML_OUTPUT_FILE`, and `TEST_FILTER`. Reports written to
`$TEST_TMPDIR/reports/` are merged into `$XML_OUTPUT_FILE` post-run.

**Consumer requirement**: place
`org.junit.platform:junit-platform-console-standalone` on the test
classpath via `runtime_deps` (typically through `rules_jvm_external`).

Use `test_class = "<fqcn>"` to select a single class; leave empty to scan
the classpath.

## Code formatting

```starlark
load("@rules_elide//elide:defs.bzl", "elide_format")

elide_format(
    name = "format",
    srcs = glob(["src/**/*.kt"]),
)
```

`bazel run //:format` formats files in place. Java sources route through
google-java-format; `.kt`/`.kts` route through ktfmt. A single target may
not mix languages — split into two `elide_format` targets if needed.

## Execution platforms and hermeticity

Compiler actions declare their toolchain files and select an execution platform
through Bazel constraints. Python runtime files are selected for the target
platform and carried in runfiles. The Python shell bootstrap does not require
host Python; native-image still needs further hermetic JDK/C toolchain work.

The repository has a BuildBuddy RBE fixture, but that does not validate every
new JVM tool or Python target remotely. See [the coverage map](docs/testing.md)
for tested configurations and remaining platform limitations.

## Examples and development

[Sample use cases](docs/examples.md) cover Java API documentation, C bindings,
KAPT/KSP generation, Python binaries/tests, and dependency diagnostics. Each
links to a runnable workspace with explicit output checks.

```sh
# Fast action/provider tests; the stub compiler does not execute Elide.
bazel test //tests:all --extra_toolchains=//tests:_test_elide_toolchain
# Real Linux x86_64 fixtures (downloads pinned distributions).
./tools/verify_integrations.sh all
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for full tests, docs regeneration, and
release-pin maintenance, and [docs/testing.md](docs/testing.md) for CI coverage.

## How it compares

| If you currently use…    | Migrate to `rules_elide` for…                                              |
|--------------------------|----------------------------------------------------------------------------|
| `rules_java`             | Embedded compiler workers, JUnit 5 native, ABI headers + source jars |
| `rules_kotlin`           | ABI compile avoidance, compile-time-compatible JavaInfo, single Elide JDK — or keep `kt_jvm_*` rules and swap only the toolchain via `register_elide_kotlin_toolchain` |
| `rules_graalvm`          | An Elide native-image rule; review the current JDK/C toolchain limitations before migrating |

`rules_elide` returns `JavaInfo` from every compile rule, so existing
`java_library` / `kt_jvm_library` consumers can depend on `elide_*` targets
unchanged.

See [`benchmarks/RESULTS.md`](benchmarks/RESULTS.md) for methodology, recorded
numbers, and how to reproduce locally via `./benchmarks/bench.sh`.
The [incremental edit matrix](benchmarks/INCREMENTAL.md) covers ABI changes,
module boundaries, dependency pruning, multi-file edits, and clean rebuilds with action logs.
Performance depends on the workload: in the matched-Java-21
[Commons Lang comparison](benchmarks/COMMONS_LANG_RESULTS.md), stock `rules_java`
had the lowest median in every incremental scenario in the initial run. A subsequent
[clean-and-incremental run](benchmarks/COMMONS_LANG_CLEAN_RESULTS.md) favored Elide
for clean rebuilds while stock retained its implementation-edit advantage.
The [production KotlinBuilder comparison](benchmarks/KOTLIN_BUILDER_RESULTS.md)
favored combined compilation for clean builds and native incremental compilation
for implementation edits. Public API edits still favored stock defaults, and
enabling incremental compilation everywhere increased clean-build and memory costs.
A [follow-up with selective IC](benchmarks/KOTLIN_WORKER_RESULTS.md) beat both stock
modes by median in all eight timing scenarios on that fixture, while using more
sampled worker memory. Microbenchmarks do not establish an application-wide speedup; compare your own
clean and incremental builds.

## Local development against a non-released elide

To validate the smoke workspace against a locally-built elide binary,
point `ELIDE_DEV_BIN` at the binary and enable `--config=dev` in
`e2e/smoke/`:

```bash
ELIDE_DEV_BIN=/abs/path/to/elide bazel build //... --config=dev
ELIDE_DEV_BIN=/abs/path/to/elide bazel test  //... --config=dev
```

See [`e2e/smoke/README.md`](e2e/smoke/README.md) for the full flow.

## Roadmap and compatibility

| Area | Status |
| --- | --- |
| Bazel | 8+; Bzlmod only. Current checks run on Bazel 9.3.0. |
| Java/Kotlin workers | Persistent and one-shot compilation supported. |
| ABI compilation | Opt-in separate header actions; KotlinBuilder supports native combined ABI output. |
| Dependency tracking | Native jdeps and opt-in unused-input pruning; KotlinBuilder strict-deps checks. |
| Annotation processing | Native KAPT/KSP2; fallback retained for unsupported builder configurations. |
| Generated source jars | Supported by KotlinBuilder; native Kotlin rules still require individual sources. |
| Stable Elide releases | Pinned through 1.6.2 alongside selected nightlies. |
| Native image | Existing rule; hermetic JDK/C toolchain integration remains work. |
| Python | Pinned overlay and opt-in rules_python runtime adapter; pure-Python binaries/tests. |
| Windows | Release pins and some launchers exist; KotlinBuilder still requires Bash and needs native Windows validation. |

## Versioning

Semantic versioning. `compatibility_level = 1` until a hard API break.

Releases are automated via [release-please](https://github.com/googleapis/release-please) and published to [GitHub Releases](https://github.com/elide-dev/rules_elide/releases) and the [Bazel Central Registry](https://registry.bazel.build/) with Sigstore-signed build provenance and SBOMs. See [RELEASING.md](RELEASING.md) for details.

## Project and security

[Security policy](SECURITY.md) · [Architecture](docs/architecture.md) ·
[Security model](docs/security-model.md) · [OpenSSF improvement plan](docs/openssf.md) ·
[Governance](GOVERNANCE.md) · [Code of conduct](CODE_OF_CONDUCT.md)

Dependabot and Renovate cover complementary dependency updates. Workflow security
checks use zizmor and ShellCheck; CodeQL is not enabled. Scorecard monitoring is
separate from Best Practices certification: no gold badge or target score is
claimed without evidence. Agent contributors should start with [AGENTS.md](AGENTS.md).

## License

Apache 2.0. See [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
