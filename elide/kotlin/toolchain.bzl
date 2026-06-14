# SPDX-License-Identifier: Apache-2.0

"""Wrapping `kt_toolchain` that swaps in the Elide KotlinBuilder shim.

This module vendors a thin wrapper around a stock rules_kotlin toolchain
instance. rules_kotlin's public `define_kt_toolchain` does not expose the
`kotlinbuilder` attribute (it is only settable on the private `_kt_toolchain`
rule). To inject the Elide builder shim we:

  1. Materialize a stock toolchain impl via `define_kt_toolchain`.
  2. Re-emit its `ToolchainInfo` with `kotlinbuilder` overridden to point at a
     config-injecting launcher (`_elide_kt_builder_launcher`) that wraps the
     `elide_kotlin_builder` persistent worker.

See `register_elide_kotlin_toolchain` for the public entry point.
"""

load("@rules_java//java/common:java_common.bzl", "java_common")
load("@rules_kotlin//kotlin:core.bzl", "define_kt_toolchain")

visibility("public")

_KT_TOOLCHAIN_TYPE = "@rules_kotlin//kotlin/internal:kt_toolchain_type"

# Canonical Bazel bash runfiles library boilerplate (v3). Resolves runfiles in
# both directory- and manifest-based layouts, on Linux/macOS and Windows.
# https://github.com/bazelbuild/bazel/blob/master/tools/bash/runfiles/runfiles.bash
_RUNFILES_INIT = """\
# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \\
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \\
  source "$0.runfiles/$f" 2>/dev/null || \\
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \\
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \\
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---
"""

# The launcher resolves the three executables via rlocation and execs the shim
# with the leading config args the Elide `Main` entrypoint expects. It MUST NOT
# write anything to stdout: in persistent-worker mode stdout carries the
# length-delimited WorkResponse stream consumed by Bazel.
# Bazel launches persistent workers (and one-shot KotlinCompile actions) with a
# scrubbed environment (`env -`), so neither PATH nor JAVA_HOME is inherited.
# `elide java` (the engine driving the shim's fast path) probes for an external
# JVM via JAVA_HOME, so the launcher exports JAVA_HOME to the rlocation of the
# Bazel-provided JDK before exec'ing the shim. This keeps the worker hermetic
# (no reliance on a system JDK or --action_env passthrough).
_LAUNCHER_TEMPLATE = """\
#!/usr/bin/env bash
{runfiles_init}
# Resolve JAVA_HOME via a concrete file inside the JDK (`bin/java`): in
# manifest-based runfiles layouts `rlocation` only resolves individual files,
# not directory roots, so we derive the home from the `java` launcher's path.
_elide_java_bin="$(rlocation {jdk_java})"
export JAVA_HOME="$(dirname "$(dirname "$_elide_java_bin")")"
# Propagate the runfiles location to child processes. The stock rules_kotlin
# KotlinBuilder (used by the fallback path) is a java_stub that locates its own
# runfiles via RUNFILES_DIR / JAVA_RUNFILES / RUNFILES_MANIFEST_FILE; under the
# scrubbed worker env it would otherwise fail with "Cannot locate runfiles
# directory". The fallback's runfiles are merged into this launcher's runfiles
# tree, so we point the children at it. (RUNFILES_DIR/RUNFILES_MANIFEST_FILE are
# set by the runfiles.bash init above when available; export them for children.)
if [ -n "${{RUNFILES_DIR:-}}" ]; then
  export RUNFILES_DIR JAVA_RUNFILES="$RUNFILES_DIR"
elif [ -d "$0.runfiles" ]; then
  export RUNFILES_DIR="$0.runfiles" JAVA_RUNFILES="$0.runfiles"
fi
if [ -n "${{RUNFILES_MANIFEST_FILE:-}}" ]; then
  export RUNFILES_MANIFEST_FILE
fi
exec "$(rlocation {shim})" \\
  --elide="$(rlocation {elide})" \\
  --fallback_builder="$(rlocation {fallback})" \\
  "$@"
"""

def _elide_kt_builder_launcher_impl(ctx):
    launcher = ctx.actions.declare_file(ctx.label.name + ".sh")

    # `<target>.files_to_run.executable.short_path` is the runfiles-relative
    # path; the runfiles library's `rlocation` maps it to the absolute path at
    # runtime. Repository-rooted short_paths (`../<repo>/...`) are normalized to
    # the canonical `<repo>/...` rlocation form.
    def _rlocation_path(exe):
        sp = exe.short_path
        if sp.startswith("../"):
            return sp[len("../"):]
        return ctx.workspace_name + "/" + sp

    # JAVA_HOME for `elide java`: the launcher derives it at runtime from the
    # rlocation of the JDK's `bin/java`. We must rlocation a concrete file (not
    # the home directory) because manifest-based runfiles layouts only key
    # individual files. `java_home` is an exec-relative path; map its first
    # `external/<repo>` segment to the canonical `<repo>/...` rlocation form.
    jdk = ctx.attr._jdk[java_common.JavaRuntimeInfo]
    java_home = jdk.java_home
    if java_home.startswith("external/"):
        jdk_home_key = java_home[len("external/"):]
    else:
        jdk_home_key = ctx.workspace_name + "/" + java_home

    content = _LAUNCHER_TEMPLATE.format(
        runfiles_init = _RUNFILES_INIT,
        jdk_java = jdk_home_key + "/bin/java",
        shim = _rlocation_path(ctx.executable.shim),
        elide = _rlocation_path(ctx.executable.elide),
        fallback = _rlocation_path(ctx.executable.fallback_builder),
    )
    ctx.actions.write(output = launcher, content = content, is_executable = True)

    # Merge the default runfiles of all three executables plus the runfiles
    # library, and include each executable's files_to_run so `rlocation` can
    # find them.
    runfiles = ctx.runfiles(
        files = [
            ctx.executable.shim,
            ctx.executable.elide,
            ctx.executable.fallback_builder,
        ],
        transitive_files = jdk.files,
    ).merge_all([
        ctx.attr.shim[DefaultInfo].default_runfiles,
        ctx.attr.elide[DefaultInfo].default_runfiles,
        ctx.attr.fallback_builder[DefaultInfo].default_runfiles,
        ctx.attr._runfiles_library[DefaultInfo].default_runfiles,
    ])

    return [DefaultInfo(
        executable = launcher,
        runfiles = runfiles,
    )]

_elide_kt_builder_launcher = rule(
    implementation = _elide_kt_builder_launcher_impl,
    doc = "Wraps the elide_kotlin_builder shim, injecting --elide/--fallback_builder config args.",
    attrs = {
        "elide": attr.label(
            doc = "The elide binary, resolved via rlocation and passed as --elide.",
            mandatory = True,
            executable = True,
            cfg = "exec",
            allow_files = True,
        ),
        "fallback_builder": attr.label(
            doc = "Stock rules_kotlin KotlinBuilder, passed as --fallback_builder.",
            mandatory = True,
            executable = True,
            cfg = "exec",
            allow_files = True,
        ),
        "shim": attr.label(
            doc = "The elide_kotlin_builder persistent-worker shim to exec.",
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
        "_jdk": attr.label(
            default = "@bazel_tools//tools/jdk:current_java_runtime",
            providers = [java_common.JavaRuntimeInfo],
            cfg = "exec",
        ),
        "_runfiles_library": attr.label(
            default = "@bazel_tools//tools/bash/runfiles",
        ),
    },
    executable = True,
    toolchains = ["@bazel_tools//tools/jdk:toolchain_type"],
)

# Fields emitted by rules_kotlin's `_kotlin_toolchain_impl` (the stock
# ToolchainInfo). Enumerated explicitly so we can copy them verbatim and
# override only `kotlinbuilder`. Mirrors the `toolchain` dict in
# rules_kotlin/kotlin/internal/toolchains.bzl. If rules_kotlin adds or renames
# a field, this list must be updated in lockstep (a missing field would drop it
# from the re-emitted ToolchainInfo).
_TOOLCHAIN_INFO_FIELDS = [
    "language_version",
    "api_version",
    "debug",
    "jvm_target",
    "kotlinbuilder",
    "builder_args",
    "jdeps_merger",
    "ksp2",
    "ksp2_invoker",
    "kotlin_home",
    "jvm_stdlibs",
    "jvm_emit_jdeps",
    "execution_requirements",
    "experimental_use_abi_jars",
    "experimental_treat_internal_as_private_in_abi_jars",
    "experimental_remove_private_classes_in_abi_jars",
    "experimental_remove_debug_info_in_abi_jars",
    "experimental_strict_kotlin_deps",
    "experimental_report_unused_deps",
    "experimental_reduce_classpath_mode",
    "experimental_build_tools_api",
    "javac_options",
    "kotlinc_options",
    "empty_jar",
    "empty_jdeps",
    "jacocorunner",
    "experimental_prune_transitive_deps",
    "experimental_strict_associate_dependencies",
]

def _elide_kt_toolchain_impl(ctx):
    base = ctx.attr.base[platform_common.ToolchainInfo]
    fields = {f: getattr(base, f) for f in _TOOLCHAIN_INFO_FIELDS}

    # Override the builder with our config-injecting launcher target. The stock
    # `kotlinbuilder` field holds the Target of the builder (the attr is
    # `executable = True`), so we pass the launcher's Target the same way.
    fields["kotlinbuilder"] = ctx.attr.kotlinbuilder

    return [platform_common.ToolchainInfo(**fields)]

_elide_kt_toolchain = rule(
    implementation = _elide_kt_toolchain_impl,
    doc = "Re-emits a stock kt_toolchain's ToolchainInfo with kotlinbuilder swapped to the Elide shim.",
    attrs = {
        "base": attr.label(
            doc = "Stock toolchain impl target providing platform_common.ToolchainInfo.",
            mandatory = True,
            providers = [platform_common.ToolchainInfo],
        ),
        "kotlinbuilder": attr.label(
            doc = "The Elide builder launcher to use as kotlinbuilder.",
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
    },
    provides = [platform_common.ToolchainInfo],
)

def register_elide_kotlin_toolchain(name, elide, fallback_builder, **kwargs):
    """Defines an Elide-backed Kotlin toolchain.

    Materializes a stock rules_kotlin toolchain, then re-emits its
    ToolchainInfo with `kotlinbuilder` swapped to a launcher that wraps the
    `elide_kotlin_builder` persistent worker (injecting the `--elide` and
    `--fallback_builder` config args the shim expects).

    The resulting `<name>` toolchain is NOT auto-registered: register it from
    your MODULE.bazel with `register_toolchains("//:<name>")`
    (`native.register_toolchains` cannot be called from a BUILD-loaded macro).

    Args:
        name: Base name. Creates `<name>` (the toolchain target to register),
            `<name>_impl` (the wrapping toolchain impl), `<name>_launcher` (the
            builder launcher), and `<name>_base` / `<name>_base_impl` (the stock
            toolchain materialized by `define_kt_toolchain`; only `_base_impl`
            is consumed -- `_base` is left unregistered).
        elide: Label of the elide binary (passed to the launcher as --elide).
        fallback_builder: Label of the stock rules_kotlin KotlinBuilder
            (e.g. `@rules_kotlin//src/main/kotlin:build`), passed as
            --fallback_builder.
        **kwargs: Forwarded to `define_kt_toolchain` (language_version,
            api_version, jvm_target, etc.).
    """
    _elide_kt_builder_launcher(
        name = name + "_launcher",
        shim = Label("//elide/kotlin/builder:elide_kotlin_builder"),
        elide = elide,
        fallback_builder = fallback_builder,
    )

    # Materialize a stock toolchain. This creates `<name>_base_impl` (the
    # ToolchainInfo provider we wrap) and `<name>_base` (a native.toolchain we
    # deliberately do NOT register).
    define_kt_toolchain(
        name = name + "_base",
        **kwargs
    )

    _elide_kt_toolchain(
        name = name + "_impl",
        base = ":" + name + "_base_impl",
        kotlinbuilder = ":" + name + "_launcher",
    )

    # NOTE: This declares the toolchain target but does NOT register it.
    # `native.register_toolchains` is not callable from a BUILD-loaded macro
    # (it is only valid in MODULE.bazel/WORKSPACE). Consumers must register the
    # resulting `<name>` target from their MODULE.bazel, e.g.
    # `register_toolchains("//:elide_kt")`.
    native.toolchain(
        name = name,
        toolchain_type = _KT_TOOLCHAIN_TYPE,
        toolchain = ":" + name + "_impl",
    )
