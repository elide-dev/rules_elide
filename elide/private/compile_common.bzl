"""Shared helpers for elide compile rules (Java, Kotlin)."""

load("@rules_java//java/common:java_common.bzl", "java_common")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("//elide:providers.bzl", "ElideInfo")
load("//elide/private:common.bzl", "collect_exported_plugins")

visibility(["//elide/..."])

TOOLCHAIN_TYPE = "//elide:toolchain_type"

def _merge_java_infos(deps):
    return [d[JavaInfo] for d in deps if JavaInfo in d]

def compile_classpath(deps):
    """Merged transitive compile-time classpath from deps providing JavaInfo.

    Args:
        deps: list[Target]. Direct dependency targets.

    Returns:
        depset[File] of jars on the compile classpath.
    """
    java_infos = _merge_java_infos(deps)
    if not java_infos:
        return depset()
    return java_common.merge(java_infos).transitive_compile_time_jars

def runtime_classpath(deps, runtime_deps):
    """Merged transitive runtime classpath from deps + runtime_deps.

    Args:
        deps: list[Target]. Direct compile dependencies.
        runtime_deps: list[Target]. Runtime-only dependencies.

    Returns:
        depset[File] of jars required at runtime.
    """
    java_infos = _merge_java_infos(deps) + _merge_java_infos(runtime_deps)
    if not java_infos:
        return depset()
    return java_common.merge(java_infos).transitive_runtime_jars

def run_compile(ctx, output_jar, subcommand, mnemonic, extra_args = None):
    """Invokes the elide CLI to compile sources into output_jar.

    Args are routed through a Bazel param file ("--flagfile=<path>", multiline
    format) and the action declares persistent + multiplex worker support, so
    the elide CLI can re-use a warm JVM when it implements the worker
    protocol; otherwise Bazel transparently falls back to standalone.

    Args:
        ctx: rule context.
        output_jar: File. Declared output classes jar.
        subcommand: string. Elide subcommand (e.g. compile-java, compile-kotlin).
        mnemonic: string. Bazel action mnemonic.
        extra_args: list[string] or None. Extra CLI args appended before srcs.
    """
    elide = ctx.toolchains[TOOLCHAIN_TYPE].elide_info
    classpath = compile_classpath(ctx.attr.deps)
    args = ctx.actions.args()
    args.set_param_file_format("multiline")
    args.use_param_file("--flagfile=%s", use_always = True)
    args.add(subcommand)
    args.add("--output-jar", output_jar)
    args.add_joined("--classpath", classpath, join_with = ctx.configuration.host_path_separator)
    if extra_args:
        for a in extra_args:
            args.add(a)
    args.add_all(ctx.files.srcs)
    ctx.actions.run(
        mnemonic = mnemonic,
        executable = elide.binary,
        arguments = [args],
        inputs = depset(direct = ctx.files.srcs, transitive = [classpath, elide.tool_files]),
        outputs = [output_jar],
        progress_message = "Compiling %{label}",
        execution_requirements = {
            "supports-multiplex-workers": "1",
            "supports-workers": "1",
            "worker-key-mnemonic": mnemonic,
        },
    )

def make_java_info(ctx, output_jar):
    """Builds the JavaInfo emitted by elide compile rules.

    Args:
        ctx: rule context.
        output_jar: File. Compiled classes jar.

    Returns:
        JavaInfo carrying output_jar plus merged transitive deps.
    """
    return JavaInfo(
        output_jar = output_jar,
        compile_jar = output_jar,
        deps = _merge_java_infos(ctx.attr.deps),
        runtime_deps = _merge_java_infos(ctx.attr.runtime_deps),
        exports = _merge_java_infos(ctx.attr.exports),
        neverlink = getattr(ctx.attr, "neverlink", False),
    )

def make_elide_info(ctx):
    """Builds the ElideInfo emitted by elide compile rules.

    Args:
        ctx: rule context.

    Returns:
        ElideInfo with propagated exported_compiler_plugins.
    """
    return ElideInfo(
        manifest = None,
        exported_compiler_plugins = collect_exported_plugins(
            ctx.attr.exports + ctx.attr.exported_compiler_plugins,
        ),
    )

_LAUNCHER_TEMPLATE = """\
#!/bin/sh
exec "{elide}" run-jvm {jvm_flags}--classpath="{classpath}" -- {main_class} "$@"
"""

def build_launcher(ctx, output_jar):
    """Writes a shell launcher running the binary via the elide toolchain.

    Args:
        ctx: rule context.
        output_jar: File. Compiled classes jar going on the classpath.

    Returns:
        (launcher_file, runfiles) tuple.
    """
    elide = ctx.toolchains[TOOLCHAIN_TYPE].elide_info
    classpath = depset(
        direct = [output_jar],
        transitive = [runtime_classpath(ctx.attr.deps, ctx.attr.runtime_deps)],
    )
    classpath_str = ctx.configuration.host_path_separator.join(
        [f.short_path for f in classpath.to_list()],
    )
    jvm_flags = "".join([f + " " for f in ctx.attr.jvm_flags])
    launcher = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(
        output = launcher,
        content = _LAUNCHER_TEMPLATE.format(
            elide = elide.binary.short_path,
            jvm_flags = jvm_flags,
            classpath = classpath_str,
            main_class = ctx.attr.main_class,
        ),
        is_executable = True,
    )
    runfiles = ctx.runfiles(
        files = [output_jar, launcher] + ctx.files.runtime_deps,
        transitive_files = depset(transitive = [elide.tool_files, classpath]),
    )
    return launcher, runfiles

COMMON_LIBRARY_ATTRS = {
    "deps": attr.label_list(providers = [[JavaInfo]]),
    "exported_compiler_plugins": attr.label_list(providers = [[ElideInfo]]),
    "exports": attr.label_list(providers = [[JavaInfo]]),
    "neverlink": attr.bool(default = False),
    "runtime_deps": attr.label_list(providers = [[JavaInfo]]),
}

COMMON_BINARY_EXTRA_ATTRS = {
    "jvm_flags": attr.string_list(),
    "main_class": attr.string(mandatory = True),
}
