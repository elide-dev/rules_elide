# Changelog

## [0.3.0](https://github.com/elide-dev/rules_elide/compare/v0.2.0...v0.3.0) (2026-06-25)


### Features

* **release:** official BCR artifact flow (immutable-release compatible) ([#48](https://github.com/elide-dev/rules_elide/issues/48)) ([19bae81](https://github.com/elide-dev/rules_elide/commit/19bae81548ce57b09e10e652e01103219df99440))


### Bug Fixes

* **release:** pass templates_ref so BCR works with the draft release ([#51](https://github.com/elide-dev/rules_elide/issues/51)) ([3f6687a](https://github.com/elide-dev/rules_elide/commit/3f6687a750b70a0725fb80490f77abcf7a2db15d))

## 0.2.0 (2026-06-25)

### Added

- `elide.use` module-extension tag for bring-your-own Elide — test against a
  custom or local build without waiting for a release in `versions.bzl`. It
  takes precedence over `elide.install` in the root module:
  - Custom tarballs + hashes: `elide.use(version = "1.3.x-mybuild",
    url_template = "https://host/elide.{os}-{cpu}.{ext}", integrity =
    {"linux_amd64": "sha256-…"})`. `integrity` is authoritative (no
    `versions.bzl` entry needed) and only its platforms get a toolchain;
    hashes are still enforced.
  - Local distribution: `elide.use(local_path = "/abs/path/to/elide")` wires the
    host-platform toolchain straight from an already-extracted Elide dir with no
    download (build is then non-reproducible).
- `rules_kotlin` KotlinBuilder interop via `register_elide_kotlin_toolchain`
  (load from `@rules_elide//elide/kotlin:toolchain.bzl`). Existing
  `kt_jvm_library` / `kt_jvm_binary` / `kt_jvm_test` targets compile through
  Elide with no BUILD-file migration — only a toolchain swap in `MODULE.bazel`.
  - Plain Kotlin / mixed Kotlin+Java: compiled via `elide kotlinc` (fast path).
  - KAPT / KSP (annotation processors): transparently delegated to the stock
    `rules_kotlin` KotlinBuilder supplied as `fallback_builder`.
  - ABI jars produced via Elide's embedded `jvm-abi-gen` when the toolchain
    enables `experimental_use_abi_jars`.
  - Real `.jdeps` output (Elide 1.3.2): the shim passes `--report-used-deps`
    (WHIPLASH #998, fixed via #1002/#1005) and classifies each classpath entry
    EXPLICIT/IMPLICIT/UNUSED, enabling `unused_deps` / reduced-classpath. Falls
    back to an empty `Deps` proto when there is no classpath to classify.
  - Compiler-plugin options (`--compiler_plugin_options`) and the requested
    Kotlin `--kotlin_{api,language}_version` are forwarded to `elide kotlinc`
    (`-P plugin:…`, `-api-version`, `-language-version`) — fixes optioned
    plugins such as Metro on the fast path (rules_elide #8).
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
- Bazel persistent worker support for the `elide javac` and `elide kotlinc`
  compile actions: each is tagged `supports-workers` + `supports-multiplex-workers`
  with the `proto` worker protocol, enabled by default. Per-request TOOL_ARGS are
  delivered via a multiline params-file WorkRequest (in the unified
  `elide <tool> [opts] -- <args>` form — Elide 1.3.1's worker accepts the `--`
  separator); Bazel injects the `--persistent_worker` startup flag itself.
  Multiplex (one warm process serving concurrent requests) is verified working
  on 1.3.1 and lifts the singleplex `--worker_max_instances` concurrency cap.
  (Workers are otherwise roughly wall-clock-neutral for elide, a native image
  with ~12 ms startup — see `benchmarks/RESULTS.md`.)
- `elide javac` compiles in a single action via the `--jar` option
  (`elide javac --jar <out> -- <args>`, Elide 1.3.1 #993), replacing the prior
  javac → `elide jar` two-action flow.
- `--@rules_elide//elide:use_workers` build flag (default `true`) toggles the
  worker path. Setting it `false` compiles each target as a one-shot
  `elide <tool> -- <args>` process — the same arg form the worker now uses.
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

- `srcjars` attribute (compile-time generated sources) not yet wired.
- `latest` CDN revision is a rolling pointer; integrity snapshot captured
  in `versions.bzl` may drift when upstream advances.
- Stable `release` channel on the CDN is not yet populated upstream (see
  `plan.md` UP-2); consumers currently pin against `nightly`/`preview`.
- `rules_kotlin` KotlinBuilder shim: the shim emits a real `.jdeps` but does
  not itself enforce `strict_kotlin_deps` (it leaves enforcement to the
  consuming `rules_kotlin` config, which reads the emitted dependency data).
  Windows workers not supported (POSIX launcher only). `elide native-image`
  still requires an external GraalVM via `JAVA_HOME` (WHIPLASH #1016/#1042 not
  yet effective as of 1.3.3), so native-image targets aren't hermetic.

[Unreleased]: https://github.com/elide-dev/rules_elide/compare/HEAD
