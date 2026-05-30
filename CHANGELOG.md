# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial scaffolding: Bzlmod-only Bazel rules for the Elide runtime.
  - `elide_java_library`, `elide_java_binary`, `elide_java_test`.
  - `elide_kotlin_library`, `elide_kotlin_binary`, `elide_kotlin_test`.
  - `elide_native_image`.
  - `elide_toolchain` + `ElideToolchainInfo` / `ElideInfo` providers.
- Hermetic per-platform toolchain via `module_extension` + `install` tag class,
  backed by an in-tree SRI integrity table.
- Persistent + multiplex worker support on every compile and native-image
  action; arguments routed through Bazel param files.
- JUnit Platform test rules with `test_class` selector or scan-classpath
  fallback.
- Stardoc-generated reference docs checked in under `docs/`.
- `e2e/smoke/` standalone workspace with env-aware local elide override.
- GitHub Actions CI matrix (Bazel 7.x/8.x × ubuntu / macos), release workflow
  with SLSA attestations, BCR publish workflow.
- `.bcr/` templates for Bazel Central Registry publication.

[Unreleased]: https://github.com/elide-dev/rules_elide/compare/HEAD
