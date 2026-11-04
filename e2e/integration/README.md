# e2e/integration

Real-toolchain integration test: a standalone Bazel workspace that activates
the `elide` extension against checksum-pinned Elide 1.6.2 and
exercises an end-to-end `elide_java_library` -> `elide_java_binary` chain.

The first `bazel build` downloads the elide binary (~500 MB), so this is
slower than the analysis-only smoke under `../smoke/` and is intended for
main-push CI runs rather than every PR.

## Run locally

```bash
bazel build :app :kt_app :javadoc :source_archive :dependencies :bytecode :bindings
bazel run //:app
```

## JVM tools and compiler metadata (Elide 1.6.2+)

```sh
bazel build :javadoc :source_archive :dependencies :bytecode :bindings
bazel build :uses_one_dep :unused_inputs_report :app :kt_app \
  --@rules_elide//elide:emit_jdeps=true \
  --@rules_elide//elide:prune_unused_inputs=true \
  --output_groups=+jdeps,+unused_inputs --remote_download_outputs=all
python3 verify_jvm_tools.py
```

Repeat the metadata build with `--@rules_elide//elide:use_workers=false` to
exercise one-shot compilation. The manual `:javadoc_theme` target probes the
Elide theme; the 1.6.2 distribution currently lacks a loadable ElideDoclet.

From the repository root, `./tools/verify_integrations.sh jvm` runs the complete
supported fixture and verifiers. It also runs `verify_pruning.py`, which checks
cache invalidation in an isolated temporary workspace. The native-image target
and the manual theme probe are deliberately excluded from that runner.
