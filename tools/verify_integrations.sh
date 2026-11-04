#!/usr/bin/env bash
# Run real-runtime fixtures and inspect outputs, using the same commands as CI.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
suite="${1:-all}"
if [[ $# -gt 0 ]]; then shift; fi
case "$suite" in jvm|kotlin|python|all) ;; *) echo "Usage: $0 [jvm|kotlin|python|all] [Bazel build options...]" >&2; exit 2 ;; esac
if [[ "$suite" == jvm || "$suite" == all ]]; then
  (
    cd "$repo/e2e/integration"
    bazel build :javadoc :source_archive :dependencies :bytecode :bindings "$@"
    for workers in true false; do
      bazel build :uses_one_dep :unused_inputs_report :app :kt_app \
        --@rules_elide//elide:emit_jdeps=true \
        --@rules_elide//elide:prune_unused_inputs=true \
        --@rules_elide//elide:use_workers="$workers" \
        --output_groups=+jdeps,+unused_inputs --remote_download_outputs=all "$@"
      python3 verify_jvm_tools.py
    done
    bazel build :app :kt_app \
      --@rules_elide//config/javac:abi_compile_avoidance=true \
      --@rules_elide//config/kotlinc:abi_compile_avoidance=true "$@"
    bazel test :HelloTest "$@"
    python3 verify_pruning.py "$@"
  )
fi
if [[ "$suite" == kotlin || "$suite" == all ]]; then
  (
    cd "$repo/e2e/kotlin_builder"
    # The verifier reads intermediate ABI/jdeps outputs outside Bazel. Materialize
    # them even on disk/remote cache hits (toplevel downloads omit these files).
    bazel build :greeter :annotated :symbols :kapt_sources :ksp_sources \
      --output_groups=+generated_classes,+stubs --remote_download_outputs=all "$@"
    python3 verify_outputs.py
  )
fi
if [[ "$suite" == python || "$suite" == all ]]; then
  (
    cd "$repo/e2e/python_overlay"
    bazel test :runtime_test \
      --@rules_python//python/config_settings:bootstrap_impl=system_python "$@"
    bazel test :runtime_test :versioned_test :other_version_test "$@"
    bazel build :app :python :java "$@"
    python3 verify_no_host_python.py
    failure_log="$(mktemp)"
    trap 'rm -f "$failure_log"' EXIT
    if bazel test :intentional_failure --test_output=errors "$@" >"$failure_log" 2>&1; then
      cat "$failure_log"
      echo "Expected the intentional Python test failure to fail Bazel" >&2
      exit 1
    fi
    if ! grep -q 'AssertionError: intentional Python test failure' "$failure_log"; then
      cat "$failure_log"
      echo "Negative fixture failed for an unexpected reason" >&2
      exit 1
    fi
    echo "Bazel correctly rejects failing Python tests."
  )
fi
