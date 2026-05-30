"""Kotlin compile rules for rules_elide.

`elide_kotlin_library` and `elide_kotlin_binary` invoke the Elide CLI to
compile mixed `.kt` / `.java` sources. Both return JavaInfo for seamless
interop with `rules_java` / `rules_kotlin` consumers, plus an ElideInfo for
Elide-specific metadata propagation.
"""

load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("//elide:providers.bzl", "ElideInfo")
load(
    "//elide/private:compile_common.bzl",
    "COMMON_BINARY_EXTRA_ATTRS",
    "COMMON_LIBRARY_ATTRS",
    "COMMON_TEST_EXTRA_ATTRS",
    "TOOLCHAIN_TYPE",
    "build_launcher",
    "build_test_launcher",
    "make_elide_info",
    "make_java_info",
    "run_compile",
)

_KOTLIN_SRCS_ATTR = {"srcs": attr.label_list(allow_files = [".kt", ".java"])}

def _kotlin_extra_args(ctx):
    extra = []
    if ctx.attr.module_name:
        extra.append("--module-name=" + ctx.attr.module_name)
    extra.extend(["--kotlinc-opt=" + o for o in ctx.attr.kotlinc_opts])
    extra.extend(["--javac-opt=" + o for o in ctx.attr.javac_opts])
    return extra

def _elide_kotlin_library_impl(ctx):
    output_jar = ctx.actions.declare_file(ctx.label.name + ".jar")
    run_compile(
        ctx,
        output_jar = output_jar,
        subcommand = "compile-kotlin",
        mnemonic = "ElideKotlinCompile",
        extra_args = _kotlin_extra_args(ctx),
    )
    return [
        make_java_info(ctx, output_jar),
        make_elide_info(ctx),
        DefaultInfo(files = depset([output_jar])),
    ]

_LIBRARY_ATTRS = dict(COMMON_LIBRARY_ATTRS)
_LIBRARY_ATTRS.update(_KOTLIN_SRCS_ATTR)
_LIBRARY_ATTRS["javac_opts"] = attr.string_list()
_LIBRARY_ATTRS["kotlinc_opts"] = attr.string_list()
_LIBRARY_ATTRS["module_name"] = attr.string()

elide_kotlin_library = rule(
    implementation = _elide_kotlin_library_impl,
    attrs = _LIBRARY_ATTRS,
    toolchains = [TOOLCHAIN_TYPE],
    provides = [JavaInfo, ElideInfo],
)

def _elide_kotlin_binary_impl(ctx):
    output_jar = ctx.actions.declare_file(ctx.label.name + ".jar")
    run_compile(
        ctx,
        output_jar = output_jar,
        subcommand = "compile-kotlin",
        mnemonic = "ElideKotlinCompile",
        extra_args = _kotlin_extra_args(ctx),
    )
    launcher, runfiles = build_launcher(ctx, output_jar)
    return [
        make_java_info(ctx, output_jar),
        make_elide_info(ctx),
        DefaultInfo(executable = launcher, runfiles = runfiles, files = depset([launcher])),
    ]

_BINARY_ATTRS = dict(_LIBRARY_ATTRS)
_BINARY_ATTRS.update(COMMON_BINARY_EXTRA_ATTRS)

elide_kotlin_binary = rule(
    implementation = _elide_kotlin_binary_impl,
    attrs = _BINARY_ATTRS,
    toolchains = [TOOLCHAIN_TYPE],
    provides = [JavaInfo, ElideInfo],
    executable = True,
)

def _elide_kotlin_test_impl(ctx):
    output_jar = ctx.actions.declare_file(ctx.label.name + ".jar")
    run_compile(
        ctx,
        output_jar = output_jar,
        subcommand = "compile-kotlin",
        mnemonic = "ElideKotlinCompile",
        extra_args = _kotlin_extra_args(ctx),
    )
    launcher, runfiles = build_test_launcher(ctx, output_jar)
    return [
        make_java_info(ctx, output_jar),
        make_elide_info(ctx),
        DefaultInfo(executable = launcher, runfiles = runfiles, files = depset([launcher])),
    ]

_TEST_ATTRS = dict(_LIBRARY_ATTRS)
_TEST_ATTRS.update(COMMON_TEST_EXTRA_ATTRS)

elide_kotlin_test = rule(
    implementation = _elide_kotlin_test_impl,
    attrs = _TEST_ATTRS,
    toolchains = [TOOLCHAIN_TYPE],
    provides = [JavaInfo, ElideInfo],
    test = True,
)
