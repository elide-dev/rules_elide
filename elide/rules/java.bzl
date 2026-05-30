"""Java compile rules for rules_elide.

`elide_java_library` and `elide_java_binary` invoke the Elide CLI to compile
Java sources. Both return JavaInfo so downstream `java_*` / `kt_*` rules can
consume their outputs transparently, and an ElideInfo for Elide-specific
metadata propagation.
"""

load("@rules_java//java/common:java_common.bzl", "java_common")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("//elide:providers.bzl", "ElideInfo")
load("//elide/private:common.bzl", "collect_exported_plugins")

_TOOLCHAIN = "//elide:toolchain_type"

def _classpath_jars(deps):
    java_infos = [d[JavaInfo] for d in deps if JavaInfo in d]
    if not java_infos:
        return depset()
    return java_common.merge(java_infos).transitive_compile_time_jars

def _run_compile(ctx, output_jar):
    elide = ctx.toolchains[_TOOLCHAIN].elide_info
    classpath = _classpath_jars(ctx.attr.deps)
    args = ctx.actions.args()
    args.add("compile-java")
    args.add("--output-jar", output_jar)
    args.add_joined("--classpath", classpath, join_with = ctx.configuration.host_path_separator)
    args.add_all(ctx.files.srcs)
    ctx.actions.run(
        mnemonic = "ElideJavaCompile",
        executable = elide.binary,
        arguments = [args],
        inputs = depset(direct = ctx.files.srcs, transitive = [classpath, elide.tool_files]),
        outputs = [output_jar],
        progress_message = "Compiling %{label}",
    )

def _java_info(ctx, output_jar):
    deps_java = [d[JavaInfo] for d in ctx.attr.deps if JavaInfo in d]
    runtime_deps_java = [d[JavaInfo] for d in ctx.attr.runtime_deps if JavaInfo in d]
    return JavaInfo(
        output_jar = output_jar,
        compile_jar = output_jar,
        deps = deps_java,
        runtime_deps = runtime_deps_java,
        exports = [d[JavaInfo] for d in ctx.attr.exports if JavaInfo in d],
        neverlink = getattr(ctx.attr, "neverlink", False),
    )

def _elide_info(ctx):
    return ElideInfo(
        manifest = None,
        exported_compiler_plugins = collect_exported_plugins(
            ctx.attr.exports + ctx.attr.exported_compiler_plugins,
        ),
    )

_COMMON_ATTRS = {
    "deps": attr.label_list(providers = [[JavaInfo]]),
    "exported_compiler_plugins": attr.label_list(providers = [[ElideInfo]]),
    "exports": attr.label_list(providers = [[JavaInfo]]),
    "neverlink": attr.bool(default = False),
    "runtime_deps": attr.label_list(providers = [[JavaInfo]]),
    "srcs": attr.label_list(allow_files = [".java"]),
}

def _elide_java_library_impl(ctx):
    output_jar = ctx.actions.declare_file(ctx.label.name + ".jar")
    _run_compile(ctx, output_jar)
    return [
        _java_info(ctx, output_jar),
        _elide_info(ctx),
        DefaultInfo(files = depset([output_jar])),
    ]

elide_java_library = rule(
    implementation = _elide_java_library_impl,
    attrs = _COMMON_ATTRS,
    toolchains = [_TOOLCHAIN],
    provides = [JavaInfo, ElideInfo],
)

_BINARY_ATTRS = dict(_COMMON_ATTRS)
_BINARY_ATTRS.update({
    "jvm_flags": attr.string_list(),
    "main_class": attr.string(mandatory = True),
})

_LAUNCHER_TEMPLATE = """\
#!/bin/sh
exec "{elide}" run-jvm {jvm_flags}--classpath="{classpath}" -- {main_class} "$@"
"""

def _elide_java_binary_impl(ctx):
    output_jar = ctx.actions.declare_file(ctx.label.name + ".jar")
    _run_compile(ctx, output_jar)
    elide = ctx.toolchains[_TOOLCHAIN].elide_info
    classpath_jars = depset(direct = [output_jar], transitive = [_classpath_jars(ctx.attr.deps)])
    classpath_str = ctx.configuration.host_path_separator.join(
        [f.short_path for f in classpath_jars.to_list()],
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
        transitive_files = depset(transitive = [elide.tool_files, classpath_jars]),
    )
    return [
        _java_info(ctx, output_jar),
        _elide_info(ctx),
        DefaultInfo(executable = launcher, runfiles = runfiles, files = depset([launcher])),
    ]

elide_java_binary = rule(
    implementation = _elide_java_binary_impl,
    attrs = _BINARY_ATTRS,
    toolchains = [_TOOLCHAIN],
    provides = [JavaInfo, ElideInfo],
    executable = True,
)
