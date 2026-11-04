# rules_elide

Bazel rules for [Elide](https://elide.dev) — Kotlin / Java compilation, JUnit
Platform tests, code formatting, and native-image builds powered by the Elide
runtime.

> **Status: pre-alpha.** Public API is unstable. Pin a specific commit or wait
> for the first tagged release.

## Why rules_elide?

Elide consolidates a polyglot runtime, a Kotlin/Java toolchain, formatters
(google-java-format, ktfmt), and ahead-of-time native-image into one binary.
For Bazel monorepos this means:

- One hermetic toolchain instead of separate `rules_java`, `rules_kotlin`,
  and `rules_graalvm` toolchains, each with their own JDK pin.
- Native-image and formatters as first-class rules, not separate rulesets.
- One small set of rules to learn (`elide_kotlin_library`, `elide_java_library`,
  `elide_native_image`, `elide_format`, ...) instead of three overlapping
  ecosystems.

## Quick start

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
| `elide_format`        | In-place format `.java` (google-java-format) or `.kt` (ktfmt)     | [docs/format.md](docs/format.md) |
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
and the 1.6.2 nightlies dated 20261102 and 20261103.

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
This provides the distribution and runtime inputs, not a `rules_python`
interpreter registration or Python dependency management.

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
    srcs = glob(["src/**/*.kt"]) + glob(["src/**/*.java"]),
)
```

`bazel run //:format` formats files in place. Java sources route through
google-java-format; `.kt`/`.kts` route through ktfmt. A single target may
not mix languages — split into two `elide_format` targets if needed.

## Hermetic and RBE / Buildfarm compatible

- No host JDK detection. No `repository_ctx.which`. The full extracted
  elide distribution is declared as runfiles of the toolchain.
- Platform-resolved via `@platforms//os:*` + `@platforms//cpu:*`.
- All file paths are relative; no developer-machine paths leak into
  outputs. Should run unchanged under Buildfarm, BuildBuddy RBE, or
  EngFlow remote execution.

## How it compares

| If you currently use…    | Migrate to `rules_elide` for…                                              |
|--------------------------|----------------------------------------------------------------------------|
| `rules_java`             | Faster compile in steady state (~2.8x on micro-bench), JUnit 5 native, ABI ijar + source jars |
| `rules_kotlin`           | Faster compile (~5.5x on micro-bench), compile-time-compatible JavaInfo, single Elide JDK — or keep `kt_jvm_*` rules and swap only the toolchain via `register_elide_kotlin_toolchain` |
| `rules_graalvm`          | Native-image without a separate toolchain or GraalVM SDK download          |

`rules_elide` returns `JavaInfo` from every compile rule, so existing
`java_library` / `kt_jvm_library` consumers can depend on `elide_*` targets
unchanged.

See [`benchmarks/RESULTS.md`](benchmarks/RESULTS.md) for methodology, recorded
numbers, and how to reproduce locally via `./benchmarks/bench.sh`.

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
| Python | Optional distribution overlay and runtime inputs; language rules deferred. |
| Windows | Release pins and some launchers exist; KotlinBuilder still requires Bash and needs native Windows validation. |

## Versioning

Semantic versioning. `compatibility_level = 1` until a hard API break.

Releases are automated via [release-please](https://github.com/googleapis/release-please) and published to [GitHub Releases](https://github.com/elide-dev/rules_elide/releases) and the [Bazel Central Registry](https://registry.bazel.build/) with Sigstore-signed build provenance and SBOMs. See [RELEASING.md](RELEASING.md) for details.

## License

Apache 2.0. See [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
