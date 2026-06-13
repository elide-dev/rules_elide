# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `rules_kotlin` KotlinBuilder interop via `register_elide_kotlin_toolchain`
  (load from `@rules_elide//elide/kotlin:toolchain.bzl`). Existing
  `kt_jvm_library` / `kt_jvm_binary` / `kt_jvm_test` targets compile through
  Elide with no BUILD-file migration — only a toolchain swap in `MODULE.bazel`.
  - Plain Kotlin / mixed Kotlin+Java: compiled via `elide kotlinc` (fast path).
  - KAPT / KSP (annotation processors): transparently delegated to the stock
    `rules_kotlin` KotlinBuilder supplied as `fallback_builder`.
  - ABI jars produced via Elide's embedded `jvm-abi-gen` when the toolchain
    enables `experimental_use_abi_jars`.
  - `.jdeps` output is a valid-but-stub proto (no per-dep classification);
    `strict_kotlin_deps` / unused-deps / reduced-classpath are effectively
    off until Elide can report used classpath entries — tracked in WHIPLASH #998.
  - `e2e/kotlin_builder/` workspace exercises both the fast path
    (`//:greeter`) and the KAPT fallback path (`//:annotated`).
- Bzlmod-only Bazel rules for the Elide runtime.
  - `elide_java_library`, `elide_java_binary`, `elide_java_test`
  - `elide_kotlin_library`, `elide_kotlin_binary`, `elide_kotlin_test`
  - `elide_native_image`
  - `elide_format` (google-java-format for `.java`, ktfmt for `.kt`)
  - `elide_toolchain`, `ElideToolchainInfo`, `ElideInfo`
- Hermetic per-platform toolchain pulled from the Elide CDN
  (`https://elide.zip/artifacts/{channel}/{version}/...`) via
  `module_extension` + `install` tag class with channel and version
  selection.
- In-tree SRI integrity table, semver-aware version comparator, full
  extracted distribution exposed as toolchain runfiles.
- Bazel persistent worker (singleplex) support for the `elide javac` and
  `elide kotlinc` compile actions: each is tagged `supports-workers` with
  the `proto` worker protocol, enabled by default. Per-request TOOL_ARGS are
  delivered via a multiline params-file WorkRequest; Bazel injects the
  `--persistent_worker` startup flag itself. (Note: workers are roughly
  wall-clock-neutral for elide, a native image with ~12 ms startup — see
  `benchmarks/RESULTS.md`.)
- `--@rules_elide//elide:use_workers` build flag (default `true`) toggles the
  above. Setting it `false` compiles each target as a one-shot
  `elide <tool> -- <args>` process — the supported way to run without workers,
  since the Bazel-native worker-off path (`--worker_max_instances=0`,
  `--strategy=...=local`) hits a broken upstream standalone mode (WHIPLASH
  #994).
- Kotlin compile pipeline supports `module_name`, `kotlinc_opts`,
  `javac_opts`, `plugins`, and `associates` (friend-paths for `internal`
  visibility).
- Compile rules emit complete `JavaInfo`: `output_jar`, ijar-derived
  `compile_jar` (via `java_common.run_ijar`), and packed `source_jars`
  (via `java_common.pack_sources`).
- JUnit Platform test launcher honouring Bazel's test runner contract
  (`TEST_TMPDIR`, `XML_OUTPUT_FILE`, `TEST_FILTER`).
- Stardoc-generated reference docs under `docs/`.
- `e2e/smoke/` standalone workspace with env-aware local elide override.
- GitHub Actions CI matrix (Bazel 7.x/8.x/9.x × ubuntu / macos) with
  SHA-pinned third-party actions, release workflow with SLSA attestations,
  BCR publish workflow, OpenSSF Scorecards.
- `.bcr/` templates referencing the `e2e/smoke` consumer module via
  `bcr_test_module`.
- `.gitattributes` export-ignore for tests / e2e / tools / .github / .bcr.

- Cross-platform launcher emission: `.sh` on POSIX, `.bat` on Windows,
  selected automatically via `@platforms//os:windows` constraint.
- Windows back in `PLATFORMS` and `ELIDE_VERSIONS["latest"]`.
- `e2e/integration/` standalone workspace exercising real `elide` toolchain
  downloaded from the CDN; CI job `integration` validates end-to-end on
  main pushes / scheduled runs.
- `benchmarks/` workspace + `bench.sh` measuring `rules_elide` against
  canonical `rules_java` / `rules_kotlin` on generated sources.
  Recorded results in `benchmarks/RESULTS.md`. Weekly scheduled CI job
  `benchmarks` re-runs and uploads results as an artifact.

### Fixes

- `elide javac` flow split into two actions: `elide javac -- -d <classes>
  -classpath ... <srcs>` writes class files, then `elide jar -- cf
  <output_jar> -C <classes> .` packs them into the output JAR. Closes the
  read-only-sandbox failure mode that prevented any real Java compile.

### Known limitations

- The Bazel-native worker-off path (`--worker_max_instances=0`,
  `--strategy=...=local`, remote execution) is broken upstream: it runs
  `elide <tool> @flagfile`, where elide's top-level parser expects a `--`
  before TOOL_ARGS, while the worker WorkRequest must omit it (WHIPLASH #994).
  Until elide parses WorkRequest arguments and the standalone `@flagfile`
  identically, run without workers via `--@rules_elide//elide:use_workers=false`
  (one-shot `elide <tool> -- <args>`) rather than the Bazel-native switches.
- `srcjars` attribute (compile-time generated sources) not yet wired.
- `latest` CDN revision is a rolling pointer; integrity snapshot captured
  in `versions.bzl` may drift when upstream advances.
- Stable `release` channel on the CDN is not yet populated upstream (see
  `plan.md` UP-2); consumers currently pin against `nightly`/`preview`.
- `rules_kotlin` KotlinBuilder shim: `.jdeps` output is a stub (no
  per-dependency classification); `strict_kotlin_deps`, unused-deps
  enforcement, and reduced-classpath mode are disabled until Elide can
  report used classpath entries (WHIPLASH #998). Windows workers not
  supported (POSIX launcher only).

[Unreleased]: https://github.com/elide-dev/rules_elide/compare/HEAD
