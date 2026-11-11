# SPDX-License-Identifier: Apache-2.0

"""A rules_java `java_toolchain` whose JavaBuilder compiles through `elide javac`.

`elide_java_toolchain` wraps `default_java_toolchain` and replaces `javabuilder` with a
launcher for `//elide/java/builder:elide_java_builder`. Requests the shim can reproduce
exactly compile with `elide javac`; the rest (annotation processors, native headers,
Error Prone/javac plugins until Elide advertises `javacPlugins`) go to the stock
JavaBuilder, kept warm as a child persistent worker. Existing `java_library`,
`java_binary` and `java_test` targets need no BUILD changes.
"""

load("@rules_java//java/common:java_common.bzl", "java_common")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("@rules_java//toolchains:default_java_toolchain.bzl", "DEFAULT_TOOLCHAIN_CONFIGURATION", "default_java_toolchain")

visibility("public")

_SHIM_BUILD = str(Label("//elide/java:shim_build"))

# rules_java's default_java_toolchain language version (an unset --java_language_version selects it).
_DEFAULT_JAVA_LANGUAGE_VERSION = "11"

def _shim_build_impl(_settings, _attr):
    return {_SHIM_BUILD: True}

# The shim is itself a JVM program built with a Java toolchain. Building it with this flag set
# keeps toolchain resolution off the Elide toolchain (whose definition requires the flag unset).
_shim_build = transition(
    implementation = _shim_build_impl,
    inputs = [],
    outputs = [_SHIM_BUILD],
)

# Bazel's JavaCompile action ships the `javabuilder` executable and `javabuilder_data`, not a
# runfiles tree. Everything the launcher needs is therefore declared as data (the `inputs` output
# group). External files (Elide, the JDK, the stock JavaBuilder) have stable exec paths; the shim's
# jars are copied next to the launcher so they share its configuration directory even under
# output-path mapping. Must not write to stdout: in worker mode stdout carries WorkResponses.
_LAUNCHER_TEMPLATE = """\
#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
export JAVA_HOME="$PWD/{jdk_home}"
export ELIDE_BAZEL=1
exec "$PWD/{elide}" java -- -cp "{classpath}" elide.java.builder.Main \\
  --elide="$PWD/{elide}" \\
  --stock_java="$JAVA_HOME/bin/java" \\
  --stock_javabuilder="$PWD/{stock}" \\
{jvm_lines}{log_line}  "$@"
"""

def _shell_quote(s):
    return "'" + s.replace("'", "'\\''") + "'"

def _launcher_impl(ctx):
    launcher = ctx.actions.declare_file(ctx.label.name + ".sh")
    jdk = ctx.attr.java_runtime[java_common.JavaRuntimeInfo]
    shim = ctx.attr.shim[0][JavaInfo]
    jars = []
    for i, jar in enumerate(shim.transitive_runtime_jars.to_list()):
        copy = ctx.actions.declare_file("%s_cp/%d_%s" % (ctx.label.name, i, jar.basename))
        ctx.actions.symlink(output = copy, target_file = jar)
        jars.append(copy)
    content = _LAUNCHER_TEMPLATE.format(
        jdk_home = jdk.java_home,
        elide = ctx.executable.elide.path,
        stock = ctx.file.stock_javabuilder.path,
        classpath = ":".join(["$here/%s_cp/%s" % (ctx.label.name, j.basename) for j in jars]),
        jvm_lines = "".join(["  " + _shell_quote("--stock_jvm_opt=" + o) + " \\\n" for o in ctx.attr.jvm_opts]),
        log_line = "  --log_routes \\\n" if ctx.attr.log_routes else "",
    )
    ctx.actions.write(output = launcher, content = content, is_executable = True)
    inputs = depset(
        direct = jars + [ctx.executable.elide, ctx.file.stock_javabuilder],
        transitive = [jdk.files, ctx.attr.elide[DefaultInfo].default_runfiles.files],
    )
    return [
        DefaultInfo(executable = launcher, runfiles = ctx.runfiles(transitive_files = inputs)),
        OutputGroupInfo(inputs = inputs),
    ]

_elide_javabuilder_launcher = rule(
    implementation = _launcher_impl,
    doc = "Wraps the Elide JavaBuilder shim with its elide binary, stock JavaBuilder and JDK.",
    attrs = {
        "elide": attr.label(mandatory = True, executable = True, cfg = "target", allow_files = True),
        "java_runtime": attr.label(mandatory = True, providers = [java_common.JavaRuntimeInfo]),
        "jvm_opts": attr.string_list(doc = "JVM options for the stock JavaBuilder (the toolchain's jvm_opts)."),
        "log_routes": attr.bool(default = False, doc = "Prefix each response with the route taken."),
        "shim": attr.label(mandatory = True, providers = [JavaInfo], cfg = _shim_build),
        "stock_javabuilder": attr.label(mandatory = True, allow_single_file = True),
    },
    executable = True,
)

def elide_java_toolchain(
        name,
        elide,
        configuration = DEFAULT_TOOLCHAIN_CONFIGURATION,
        target_settings = [],
        exec_compatible_with = [],
        target_compatible_with = [],
        log_routes = False,
        **kwargs):
    """Defines and declares a Java toolchain whose JavaBuilder compiles through Elide.

    Args:
        name: Toolchain name. Creates `<name>` (the java_toolchain), `<name>_javabuilder`
            (the launcher) and `<name>_definition` (the `toolchain()` to register; with rules_java's
            default language version also `<name>_default_definition`, for an unset
            `--java_language_version`). Register them ahead of the stock Java toolchains.
        elide: The execution platform's `@elide_<os>_<cpu>//:elide` (binary plus distribution).
        configuration: Base `default_java_toolchain` configuration.
        target_settings: Extra settings gating the definition, e.g. a killswitch flag.
        exec_compatible_with: Execution platform constraints of the definition.
        target_compatible_with: Target platform constraints of the definition.
        log_routes: Prefix each compile's output with the route taken (debugging).
        **kwargs: Forwarded to `default_java_toolchain` (javacopts, jvm_opts, java_runtime, ...).
    """
    settings = dict(configuration)
    settings.update(kwargs)
    _elide_javabuilder_launcher(
        name = name + "_javabuilder",
        elide = elide,
        java_runtime = settings["java_runtime"],
        jvm_opts = settings.get("jvm_opts", []),
        log_routes = log_routes,
        shim = Label("//elide/java/builder:lib"),
        stock_javabuilder = settings["javabuilder"],
        tags = ["manual"],
    )
    native.filegroup(
        name = name + "_javabuilder_inputs",
        srcs = [":" + name + "_javabuilder"],
        output_group = "inputs",
        tags = ["manual"],
    )
    toolchain_kwargs = dict(kwargs)
    toolchain_kwargs["javabuilder"] = ":" + name + "_javabuilder"
    toolchain_kwargs["javabuilder_data"] = toolchain_kwargs.get("javabuilder_data", []) + [":" + name + "_javabuilder_inputs"]

    # The shim handles one request at a time.
    toolchain_kwargs.setdefault("javac_supports_multiplex_workers", False)
    default_java_toolchain(
        name = name,
        configuration = configuration,
        toolchain_definition = False,
        **toolchain_kwargs
    )

    # Mirrors default_java_toolchain's definitions: one for --java_language_version=<source_version>, and for
    # rules_java's default language version also one for an unset --java_language_version.
    versions = {name + "_definition": settings["source_version"]}
    if settings["source_version"] == _DEFAULT_JAVA_LANGUAGE_VERSION:
        versions[name + "_default_definition"] = ""
    for definition, version in versions.items():
        native.config_setting(
            name = definition + "_version_setting",
            values = {"java_language_version": version},
            visibility = ["//visibility:private"],
        )
        native.toolchain(
            name = definition,
            toolchain_type = Label("@bazel_tools//tools/jdk:toolchain_type"),
            target_settings = [definition + "_version_setting", Label("//elide/java:not_shim_build")] + target_settings,
            toolchain = name,
            exec_compatible_with = exec_compatible_with,
            target_compatible_with = target_compatible_with,
        )
