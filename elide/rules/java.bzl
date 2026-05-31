# SPDX-License-Identifier: Apache-2.0

"""Java compile rules for rules_elide.

`elide_java_library` / `_binary` / `_test` drive `elide javac` to compile
`.java` sources. Every rule returns `JavaInfo` (with an `ijar`-derived
`compile_jar` and a packed `source_jar`) so downstream `java_*` / `kt_*`
rules consume the outputs without any adapter, plus `ElideInfo` for
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
    "pack_source_jar",
    "run_javac",
)

_JAVA_SRCS_ATTR = {"srcs": attr.label_list(
    doc = "Java source files to compile.",
    allow_files = [".java"],
)}
_JAVA_TOOLCHAINS = [TOOLCHAIN_TYPE, "@bazel_tools//tools/jdk:toolchain_type"]

def _elide_java_library_impl(ctx):
    output_jar = ctx.actions.declare_file(ctx.label.name + ".jar")
    run_javac(ctx, output_jar)
    source_jar = pack_source_jar(ctx)
    return [
        make_java_info(ctx, output_jar, source_jar = source_jar),
        make_elide_info(ctx),
        DefaultInfo(files = depset([output_jar])),
    ]

_LIBRARY_ATTRS = dict(COMMON_LIBRARY_ATTRS)
_LIBRARY_ATTRS.update(_JAVA_SRCS_ATTR)
_LIBRARY_ATTRS["javac_opts"] = attr.string_list(
    doc = "Flags appended to the `elide javac --` invocation.",
)

elide_java_library = rule(
    implementation = _elide_java_library_impl,
    attrs = _LIBRARY_ATTRS,
    toolchains = _JAVA_TOOLCHAINS,
    provides = [JavaInfo, ElideInfo],
)

def _elide_java_binary_impl(ctx):
    output_jar = ctx.actions.declare_file(ctx.label.name + ".jar")
    run_javac(ctx, output_jar)
    source_jar = pack_source_jar(ctx)
    launcher, runfiles = build_launcher(ctx, output_jar)
    return [
        make_java_info(ctx, output_jar, source_jar = source_jar),
        make_elide_info(ctx),
        DefaultInfo(executable = launcher, runfiles = runfiles, files = depset([launcher])),
    ]

_BINARY_ATTRS = dict(_LIBRARY_ATTRS)
_BINARY_ATTRS.update(COMMON_BINARY_EXTRA_ATTRS)

elide_java_binary = rule(
    implementation = _elide_java_binary_impl,
    attrs = _BINARY_ATTRS,
    toolchains = _JAVA_TOOLCHAINS,
    provides = [JavaInfo, ElideInfo],
    executable = True,
)

def _elide_java_test_impl(ctx):
    output_jar = ctx.actions.declare_file(ctx.label.name + ".jar")
    run_javac(ctx, output_jar)
    source_jar = pack_source_jar(ctx)
    launcher, runfiles = build_test_launcher(ctx, output_jar)
    return [
        make_java_info(ctx, output_jar, source_jar = source_jar),
        make_elide_info(ctx),
        DefaultInfo(executable = launcher, runfiles = runfiles, files = depset([launcher])),
    ]

_TEST_ATTRS = dict(_LIBRARY_ATTRS)
_TEST_ATTRS.update(COMMON_TEST_EXTRA_ATTRS)

elide_java_test = rule(
    implementation = _elide_java_test_impl,
    attrs = _TEST_ATTRS,
    toolchains = _JAVA_TOOLCHAINS,
    provides = [JavaInfo, ElideInfo],
    test = True,
)
