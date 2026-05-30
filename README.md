# rules_elide

Bazel rules for [Elide](https://elide.dev) — Kotlin / Java compilation, JUnit
Platform tests, and native-image builds powered by the Elide runtime.

> **Status: pre-alpha.** Public API is unstable. Pin a specific commit or wait
> for the first tagged release. The CLI contract between these rules and the
> Elide runtime is still being aligned; see the *Compatibility* section below.

## Why rules_elide?

Elide consolidates a polyglot runtime, a Kotlin/Java toolchain, and ahead-of-time
native-image into one binary. For Bazel monorepos this means:

- One hermetic toolchain instead of separate `rules_java`, `rules_kotlin`, and
  `rules_graalvm` toolchains, each with their own JDK pin.
- Persistent + multiplex workers keep a warm JVM across compile actions — the
  same perf pattern Uber relies on in `uber-common/rules_kotlin`.
- Native-image as a first-class rule, not a separate ruleset.
- One small set of rules to learn (`elide_kotlin_library`, `elide_java_library`,
  `elide_native_image`, …) instead of three overlapping ecosystems.

## Quick start

`MODULE.bazel`:

```starlark
bazel_dep(name = "rules_elide", version = "0.0.1")

elide = use_extension("@rules_elide//elide:extensions.bzl", "elide")
elide.install(version = "1.0.0")
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

| Rule                  | Purpose                                             | Reference |
|-----------------------|-----------------------------------------------------|-----------|
| `elide_java_library`  | Compile `.java` sources into a JavaInfo-bearing jar | [docs/java.md](docs/java.md) |
| `elide_java_binary`   | `_library` + launcher (`elide run-jvm`)             | [docs/java.md](docs/java.md) |
| `elide_java_test`     | `_library` + JUnit Platform launcher                | [docs/java.md](docs/java.md) |
| `elide_kotlin_library`| Compile mixed `.kt` / `.java` sources               | [docs/kotlin.md](docs/kotlin.md) |
| `elide_kotlin_binary` | `_library` + launcher                               | [docs/kotlin.md](docs/kotlin.md) |
| `elide_kotlin_test`   | `_library` + JUnit Platform launcher                | [docs/kotlin.md](docs/kotlin.md) |
| `elide_native_image`  | Native AOT binary from JavaInfo deps                | [docs/native_image.md](docs/native_image.md) |
| `elide_toolchain`     | Wrap an elide binary as a Bazel toolchain           | [docs/toolchain.md](docs/toolchain.md) |

Providers: `ElideToolchainInfo`, `ElideInfo` ([docs/providers.md](docs/providers.md)).
Top-level entry point: [`@rules_elide//elide:defs.bzl`](docs/defs.md).

## Toolchain resolution

The `elide` module extension downloads the elide release artifact for the host
platform from
`https://github.com/elide-dev/WHIPLASH/releases/download/v{VERSION}/elide-{VERSION}-{OS}-{CPU}.{EXT}`,
verifies it against an in-tree SRI integrity table, and exposes it as a
`toolchain_type` at `@rules_elide//elide:toolchain_type`.

Supported platforms:

| OS      | CPU       | Constraint                                              |
|---------|-----------|---------------------------------------------------------|
| Linux   | amd64     | `@platforms//os:linux` + `@platforms//cpu:x86_64`       |
| Linux   | arm64     | `@platforms//os:linux` + `@platforms//cpu:aarch64`      |
| macOS   | arm64     | `@platforms//os:macos` + `@platforms//cpu:aarch64`      |
| Windows | amd64     | `@platforms//os:windows` + `@platforms//cpu:x86_64`     |

`MODULE.bazel.lock` records the resolved hashes (the extension marks itself
`reproducible = True`), so air-gapped CI runs replay deterministically.

## Persistent + multiplex workers

Every compile and native-image action declares:

- `supports-workers = "1"`
- `supports-multiplex-workers = "1"`
- `worker-key-mnemonic = "<mnemonic>"`

Arguments are routed through Bazel param files (`--flagfile=%s`, multiline),
which is the wire format Bazel uses for worker requests. If the elide CLI
implements the Bazel WorkRequest / WorkResponse protocol, actions reuse a warm
JVM; otherwise Bazel transparently falls back to standalone execution.

## JUnit Platform tests

`elide_java_test` and `elide_kotlin_test` are first-class JUnit 5 / JUnit
Platform test rules. The launcher invokes `elide run-test --junit-platform`
with either `--test-class=<class>` (when `test_class` is set on the target)
or `--scan-classpath` (when it isn't).

## Hermetic and RBE / Buildfarm compatible

- No host JDK detection. No `repository_ctx.which`. All tools are declared as
  runfiles of the toolchain.
- All compile actions go through param files — classpath length cannot overflow
  the OS arg limit.
- Toolchain is platform-resolved via `@platforms//os:*` + `@platforms//cpu:*`;
  bit-identical outputs across macOS-dev and Linux-CI.
- Remote build execution (Buildfarm, BuildBuddy RBE, EngFlow) is supported on
  the same execution requirements as `rules_kotlin`.

## How it compares

| If you currently use…    | Migrate to `rules_elide` for…                                              |
|--------------------------|----------------------------------------------------------------------------|
| `rules_java`             | Faster compile (Elide-native), persistent workers per-rule, JUnit 5 native |
| `rules_kotlin`           | Same rule surface (compile-time-compatible JavaInfo), single Elide JDK     |
| `rules_graalvm`          | Native-image without a separate toolchain or GraalVM SDK download          |

`rules_elide` returns `JavaInfo` from every compile rule, so existing
`java_library` / `kt_jvm_library` consumers can depend on `elide_*` targets
unchanged.

## Local development against a non-released elide

To validate the smoke workspace against a locally-built elide binary
(while a release isn't yet wired up), point `ELIDE_BIN` at the binary and
enable `--config=dev` in `e2e/smoke/`:

```bash
ELIDE_BIN=/abs/path/to/elide bazel build //... --config=dev
ELIDE_BIN=/abs/path/to/elide bazel test  //... --config=dev
```

See [`e2e/smoke/README.md`](e2e/smoke/README.md) for the full flow.

## Compatibility

| Layer                       | Status                                                            |
|-----------------------------|-------------------------------------------------------------------|
| Bazel                       | 7.4.0+ (Bzlmod-only; legacy WORKSPACE is not supported)            |
| Elide CLI subcommands       | Pending alignment with upstream — see followups in repo issues    |
| Persistent worker protocol  | Wired on the rules side; gated by Elide CLI worker support        |
| BCR (Bazel Central Registry)| Templates in `.bcr/`; first publication after first tagged release |

## Versioning

Semantic versioning. `compatibility_level = 1` until a hard API break, then
bumped per Bzlmod policy.

## License

Apache 2.0. See [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports and PRs are welcome.
