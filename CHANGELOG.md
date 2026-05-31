# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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

### Known limitations

- Persistent worker support requires Elide CLI WorkRequest/WorkResponse
  protocol implementation (pending upstream); rules currently invoke the
  CLI as one-shot processes.
- Windows omitted from `PLATFORMS` until `.bat` launchers ship.
- `srcjars` attribute (compile-time generated sources) not yet wired.
- `latest` CDN revision is a rolling pointer; integrity snapshot captured
  in `versions.bzl` may drift when upstream advances.

[Unreleased]: https://github.com/elide-dev/rules_elide/compare/HEAD
