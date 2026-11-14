# Contributing

Use Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`) and open a
PR against `main` unless the maintainer has agreed to a different workflow.

## Development setup

Use Bazelisk to honor `.bazelversion`. The module supports Bazel 8+ with Bzlmod;
CI checks analysis tests on Bazel 8 and 9, on Linux and macOS. Bash, Python 3,
and standard POSIX utilities run the integration verification scripts.

The root `MODULE.bazel` installs the pinned Elide release for execution tests.
Downloads are checksum-verified and can be large. Pass `--distdir=/path/to/archives`
to reuse downloaded release artifacts. Python integration additionally needs the
matching `elide.python.<os>-<cpu>.tgz` overlay. Lockfiles are generated locally
and intentionally not committed across Bazel major versions.

## Choose the appropriate checks

Fast analysis tests inspect actions, providers, declared inputs, and invalid
configurations without executing Elide:

```sh
bazel test //tests:all --extra_toolchains=//tests:_test_elide_toolchain
```

Full root tests also execute KotlinBuilder unit/protocol tests through Elide:

```sh
bazel test //... \
  --java_runtime_version=remotejdk_21 \
  --tool_java_runtime_version=remotejdk_21
```

Do not use the stub toolchain for execution tests: it deliberately emits no
compiler outputs. The JDK 21 runtime flags are needed for the builder test
bytecode, independently of the host JDK.

For runtime/rule changes, run the relevant real-toolchain checks:

```sh
./tools/verify_integrations.sh jvm
./tools/verify_integrations.sh java_builder
./tools/verify_integrations.sh kotlin
./tools/verify_integrations.sh python
# Or every suite; extra arguments are forwarded to Bazel build/test commands:
./tools/verify_integrations.sh all --distdir=/path/to/archives
```

The JVM checks include worker/one-shot dependency reports and a cache-invalidation
experiment in a temporary workspace. They do not edit your checkout. The Python
checks cover both bootstrap modes; the legacy mode requires host Python, while
the shell mode is also tested with Python removed from PATH.

See [the coverage map](docs/testing.md) for assertions, CI scope, and known gaps,
and [sample use cases](docs/examples.md) for runnable consumer examples.

For performance work, run the benchmark helper tests and retain the raw samples:

```sh
python3 -m unittest discover -s benchmarks -p '*_test.py'
python3 benchmarks/incremental_matrix.py --languages java --profiles
```

See the [performance target ledger](benchmarks/PERFORMANCE_TARGETS.md). Compare
stock defaults and supported optimized stock modes; report regressions and missing
measurements. Traces contain bucketed memory counters, not peak process RSS.

## Updating public APIs and release pins

- Keep `elide/defs.bzl`, the relevant `bzl_library` dependencies, generated
  references, README tables, and runnable fixtures in sync when adding rules.
- Regenerate references with `./tools/update_docs.sh`; do not edit generated
  API tables by hand. Narrative guides such as `docs/python.md` are handwritten.
- For release updates, update integrity tables in `elide/private/versions.bzl`,
  version tests, and selected fixtures. Overlay checksums must match the base
  version/platform. Do not manufacture pins for unpublished nightlies.
- Add analysis tests for input/provider contracts and errors. Use real-runtime
  assertions for generated artifact contents, processor behavior, or cache
  correctness; inspecting command-line flags alone cannot establish those.
- Keep unsupported upstream paths explicit. The themed Javadoc probe is manual;
  native-image integration is not part of the passing fixture runner.

Run `pre-commit run --all-files` for repository lint checks. For a focused
Starlark edit, `buildifier -mode=check -lint=warn path/to/file.bzl` is useful.
Never commit `user.bazelrc`, credentials, generated Bazel outputs, or local
benchmark results.

## Review, security, and starter work

Follow [the code of conduct](CODE_OF_CONDUCT.md) and
[review expectations](GOVERNANCE.md#review-expectations). Use four-space Starlark
indentation/buildifier, the surrounding Kotlin style, and ShellCheck-compatible
Bash for executable helpers. `.editorconfig` and pre-commit define formatting and
lint checks; do not claim a formatter enforces languages it does not check.

For workflow/policy changes:

```sh
python3 -m pip install -r requirements-dev.txt
zizmor --offline --format plain .github/workflows
python3 -m pytest tools/repository_policy_test.py tools/sbom_enrich_test.py tools/python_launcher_test.py
```

[The OpenSSF plan](docs/openssf.md#useful-starter-contributions) lists small,
useful contributions and the evidence still needed for higher assurance.
Dependencies are updated through reviewed PRs; version upgrades are not
permission to regenerate runtime checksums without verifying the artifacts.

## License

By contributing, you certify that you have the right to submit your contribution
under the project's [LICENSE](LICENSE) (Apache 2.0).
