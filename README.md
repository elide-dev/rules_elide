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
elide.install(version = "latest", channel = "nightly")
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

Providers: `ElideToolchainInfo`, `ElideInfo` ([docs/providers.md](docs/providers.md)).
Top-level entry point: [`@rules_elide//elide:defs.bzl`](docs/defs.md).

## Toolchain resolution

The `elide` module extension downloads the elide release artifact for the
host platform from the public Elide CDN:

```
https://elide.zip/artifacts/{channel}/{version}/elide.{os}-{cpu}.{ext}
```

Each artifact is verified against an in-tree SRI integrity table.

- **channel**: `nightly`, `preview`, or `release`. Pre-alpha: only
  `nightly` and `preview` are populated upstream.
- **version**: any concrete revision (e.g. `1.2.0-beta`) or the rolling
  pointer `latest`. With `latest`, integrity reflects the snapshot
  captured in `elide/private/versions.bzl`; if the CDN advances, regenerate
  the integrity row.

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

## Compile-rule outputs (`JavaInfo`)

Every compile rule returns a complete `JavaInfo`:

- `output_jar` — the full class JAR produced by `elide javac --jar` /
  `elide kotlinc -d`.
- `compile_jar` — ABI jar derived via `java_common.run_ijar` for fast
  downstream incremental rebuilds.
- `source_jars` — sources packaged via `java_common.pack_sources`
  (IDE sync / Maven publish friendly).

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
| `rules_java`             | Faster compile (Elide-native), JUnit 5 native, ABI ijar + source jars      |
| `rules_kotlin`           | Same rule surface (compile-time-compatible JavaInfo), single Elide JDK     |
| `rules_graalvm`          | Native-image without a separate toolchain or GraalVM SDK download          |

`rules_elide` returns `JavaInfo` from every compile rule, so existing
`java_library` / `kt_jvm_library` consumers can depend on `elide_*` targets
unchanged.

## Local development against a non-released elide

To validate the smoke workspace against a locally-built elide binary,
point `ELIDE_DEV_BIN` at the binary and enable `--config=dev` in
`e2e/smoke/`:

```bash
ELIDE_DEV_BIN=/abs/path/to/elide bazel build //... --config=dev
ELIDE_DEV_BIN=/abs/path/to/elide bazel test  //... --config=dev
```

See [`e2e/smoke/README.md`](e2e/smoke/README.md) for the full flow.

## Roadmap

| Item                              | Status                                                |
|-----------------------------------|-------------------------------------------------------|
| Windows `.bat` launcher           | Pending — Windows platform omitted from `PLATFORMS`   |
| Persistent worker protocol        | Pending Elide CLI WorkRequest/WorkResponse support    |
| Kotlin `srcjars` (extract+compile)| Pending                                               |
| Stable `release` channel populated| Pending upstream                                      |
| BCR (Bazel Central Registry)      | Templates in `.bcr/`; first publication after release |

## Compatibility

| Layer                       | Status                                                                  |
|-----------------------------|-------------------------------------------------------------------------|
| Bazel                       | 7.4.0+ (Bzlmod-only; legacy `WORKSPACE` is not supported)               |

## Versioning

Semantic versioning. `compatibility_level = 1` until a hard API break.

## License

Apache 2.0. See [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
