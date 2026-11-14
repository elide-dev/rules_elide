# Changelog

## [0.8.0](https://github.com/elide-dev/rules_elide/compare/v0.7.0...v0.8.0) (2026-11-14)


### Features

* add opt-in combined Kotlin compilation and ABI emission ([576a69f](https://github.com/elide-dev/rules_elide/commit/576a69feff702cae7cdee6bba75d9597c43dbf0b))
* **cc:** build hermetic C executables with Elide's bundled LLVM ([#114](https://github.com/elide-dev/rules_elide/issues/114)) ([f22a00a](https://github.com/elide-dev/rules_elide/commit/f22a00a616108dce129ce476e71b19a84a508727))
* emit Java ABI headers alongside full compilation ([1c4d231](https://github.com/elide-dev/rules_elide/commit/1c4d231716568ea490288e2ee179553c887bbb86))
* **java:** JavaBuilder shim routing java_library compiles through elide javac ([#106](https://github.com/elide-dev/rules_elide/issues/106)) ([5376f65](https://github.com/elide-dev/rules_elide/commit/5376f65d82c7b6d3d284ef7909afbdf5b394fa25))
* **kotlin:** run external compiler plugins on Elide when it supports them ([#109](https://github.com/elide-dev/rules_elide/issues/109)) ([e2dd95b](https://github.com/elide-dev/rules_elide/commit/e2dd95b826bbe46d2a25fb796f3a8b0e1823f1f8))
* select ABI compilation strategy per JVM target ([f3de522](https://github.com/elide-dev/rules_elide/commit/f3de522d8ffcf5d25cfd1949fcba9300cad58505))
* select Kotlin incremental compilation per target ([abbca75](https://github.com/elide-dev/rules_elide/commit/abbca7551de3104f8e4e26e49d18c5ebe129bd4c))


### Bug Fixes

* align Java benchmark targets and verify emitted bytecode ([0f5d896](https://github.com/elide-dev/rules_elide/commit/0f5d8960d1b50c23058794de6c87a43174f3f91a))
* install Bazelisk explicitly for benchmark runner cleanup ([302506a](https://github.com/elide-dev/rules_elide/commit/302506ad9de0eb3397e0489d3dd39c25d3beff90))
* **java:** make elide_java_* jars reproducible ([#108](https://github.com/elide-dev/rules_elide/issues/108)) ([5592606](https://github.com/elide-dev/rules_elide/commit/5592606576fcd1444a9ba37904cb597339a273fb)), closes [#119](https://github.com/elide-dev/rules_elide/issues/119)
* **kotlin:** never drop compiler plugins delivered in --plugins_payload ([#107](https://github.com/elide-dev/rules_elide/issues/107)) ([2ce1a7f](https://github.com/elide-dev/rules_elide/commit/2ce1a7fa0275a219cf764e0039070a38b126613b))
* **kotlin:** ship the elide distribution with the KotlinBuilder launcher ([#105](https://github.com/elide-dev/rules_elide/issues/105)) ([e681ddc](https://github.com/elide-dev/rules_elide/commit/e681ddc4180d83da00e21ad848edf861d5d3aabb))
* preserve complete Kotlin incremental outputs across Bazel actions ([09b7e56](https://github.com/elide-dev/rules_elide/commit/09b7e5650c597b39108ee219dd5eb58794512e4c))
* propagate Kotlin stdlib to Java consumers ([09e5049](https://github.com/elide-dev/rules_elide/commit/09e5049992d02e2e8e092a53ab1b21816c914c23))
* Python launcher, remote Kotlin distribution, pin Elide 1.6.3 ([#113](https://github.com/elide-dev/rules_elide/issues/113)) ([cb9e0fd](https://github.com/elide-dev/rules_elide/commit/cb9e0fd20514e5647cfb15c94aeb3789794a1d66))
* reuse verified Elide distribution in isolated CodSpeed fixtures ([7553d8b](https://github.com/elide-dev/rules_elide/commit/7553d8bb7dbc9dea1ba6b98f3c46bd68887febca))


### Performance Improvements

* activate eligible Java classpath cache requests ([66a71b7](https://github.com/elide-dev/rules_elide/commit/66a71b70ae5e61425b54fd383dd1b295729d8fb6))
* exclude LLVM from JVM compiler action inputs ([a9a0e8e](https://github.com/elide-dev/rules_elide/commit/a9a0e8ebc038e5be1ce5052cfa066d8e4dbb607c))
* isolate jextract resources from JVM compiler inputs ([9353ffc](https://github.com/elide-dev/rules_elide/commit/9353ffcc53509681002f9c827676671c95da8f1d))
* omit native static libraries from JVM action inputs ([3abfccc](https://github.com/elide-dev/rules_elide/commit/3abfccc9b8c15603e7dff53371c15ae24db3a0a9))
* remove protobuf bootstrap from native IC worker ([dcb303f](https://github.com/elide-dev/rules_elide/commit/dcb303fa5fd59a60c14b1dc258de998bd6ee21c2))
* retain Kotlin incremental state across classpath updates ([b1d08e5](https://github.com/elide-dev/rules_elide/commit/b1d08e593c49a0be31c07d5ca8d481e1647a3e2a))

## [0.7.0](https://github.com/elide-dev/rules_elide/compare/v0.6.1...v0.7.0) (2026-11-04)


### Features

* adopt Elide 1.6 runtimes and native JVM builder capabilities ([9b59096](https://github.com/elide-dev/rules_elide/commit/9b59096d2c91048e8a35892ac63ccff16499f94f))
* **kotlin:** extend abi compile-avoidance to mixed kotlin+java targets ([#36](https://github.com/elide-dev/rules_elide/issues/36)) ([dad26e5](https://github.com/elide-dev/rules_elide/commit/dad26e56affc8aea185a6579ece983dc516920e6))
* support elide 1.6.0 and make it the default ([#90](https://github.com/elide-dev/rules_elide/issues/90)) ([a234522](https://github.com/elide-dev/rules_elide/commit/a23452248460302fca0ec8b93a8a76f8f9359cc1))
* wire Elide Python overlays into rules_python toolchains ([74bf186](https://github.com/elide-dev/rules_elide/commit/74bf186de1c82e6774c8244beee3c5c089bc66cb))


### Bug Fixes

* **deps:** bump default Elide runtime to 1.3.6+20260628 (latest nightly) ([#71](https://github.com/elide-dev/rules_elide/issues/71)) ([9d9c639](https://github.com/elide-dev/rules_elide/commit/9d9c639e6e3bd8feea1db8c9f65258a4da5788f2))
* **rbe:** pin BuildBuddy RBE to managed executors ([#88](https://github.com/elide-dev/rules_elide/issues/88)) ([0bdd808](https://github.com/elide-dev/rules_elide/commit/0bdd808dd2d1b5cfa09ef9ec9ce0cc6166d5cce3))

## [0.6.1](https://github.com/elide-dev/rules_elide/compare/v0.6.0...v0.6.1) (2026-06-27)


### Bug Fixes

* **bcr:** clear ANDROID_HOME for repo rules so macOS smoke build analyzes ([#68](https://github.com/elide-dev/rules_elide/issues/68)) ([243fbaa](https://github.com/elide-dev/rules_elide/commit/243fbaafc20d92f0e9686ccc7306368e8ec56817))

## [0.6.0](https://github.com/elide-dev/rules_elide/compare/v0.5.1...v0.6.0) (2026-06-26)


### Features

* **release:** build releases via release_ruleset (verifiable BCR attestations) ([#66](https://github.com/elide-dev/rules_elide/issues/66)) ([581cac4](https://github.com/elide-dev/rules_elide/commit/581cac4db4bf06fab12c38228c8fdebd8e0b0a1e))

## [0.5.1](https://github.com/elide-dev/rules_elide/compare/v0.5.0...v0.5.1) (2026-06-25)


### Bug Fixes

* **bcr:** move module() comment out so version-stamp can't corrupt MODULE.bazel ([#62](https://github.com/elide-dev/rules_elide/issues/62)) ([6c1eac3](https://github.com/elide-dev/rules_elide/commit/6c1eac326439e1e74e039a255c18a371ab81e6ba))

## [0.5.0](https://github.com/elide-dev/rules_elide/compare/v0.4.0...v0.5.0) (2026-06-25)


### Features

* **release:** trusted BCR release — presubmit fixes, CLA identity, signed tags ([#58](https://github.com/elide-dev/rules_elide/issues/58)) ([5b680b9](https://github.com/elide-dev/rules_elide/commit/5b680b966af6bd72f5c5fee083e8b110435e822f))

## [0.4.0](https://github.com/elide-dev/rules_elide/compare/v0.3.0...v0.4.0) (2026-06-25)


### Features

* **release:** target 0.4.0; run BCR publish in the `bcr` environment ([#54](https://github.com/elide-dev/rules_elide/issues/54)) ([58a61bb](https://github.com/elide-dev/rules_elide/commit/58a61bb1f4b38b88a4b2465060867eb1a22124cb))

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
