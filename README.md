# rules_elide

Bazel rules for [Elide](https://elide.dev) — Kotlin / Java compilation and native-image builds powered by the Elide runtime.

> **Status: pre-alpha.** Public API is unstable. Pin a specific commit or wait for the first tagged release.

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
load("@rules_elide//elide:defs.bzl", "elide_kotlin_library")

elide_kotlin_library(
    name = "lib",
    srcs = glob(["src/**/*.kt"]),
)
```

## Requirements

- Bazel 7.4.0 or newer (Bzlmod-only; legacy `WORKSPACE` is not supported).
- Linux (amd64/arm64), macOS (arm64), or Windows (amd64).

## License

Apache 2.0. See [LICENSE](LICENSE).
