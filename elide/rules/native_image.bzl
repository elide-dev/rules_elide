# SPDX-License-Identifier: Apache-2.0

"""Native image rule for rules_elide.

`elide_native_image` runs `elide native-image` to compile JVM bytecode
(provided via JavaInfo deps) into a standalone native executable.
"""

load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load(
    "//elide/private:compile_common.bzl",
    "TOOLCHAIN_TYPE",
    "runtime_classpath",
)

def _elide_native_image_impl(ctx):
    elide = ctx.toolchains[TOOLCHAIN_TYPE].elide_info
    output = ctx.actions.declare_file(ctx.label.name)
    classpath = runtime_classpath(ctx.attr.deps, [])
    sep = ctx.configuration.host_path_separator

    args = ctx.actions.args()
    args.add("native-image")
    args.add("--")
    args.add("--no-fallback")
    args.add_joined("-classpath", classpath, join_with = sep)
    args.add("-o", output)
    args.add(ctx.attr.main_class)
    for opt in ctx.attr.native_image_opts:
        args.add(opt)

    ctx.actions.run(
        mnemonic = "ElideNativeImage",
        executable = elide.binary,
        arguments = [args],
        inputs = depset(transitive = [classpath, elide.tool_files]),
        outputs = [output],
        progress_message = "Building native image %{label}",
    )
    runfiles = ctx.runfiles(files = [output])
    return [DefaultInfo(executable = output, runfiles = runfiles, files = depset([output]))]

elide_native_image = rule(
    implementation = _elide_native_image_impl,
    attrs = {
        "deps": attr.label_list(
            doc = "JVM dependencies whose runtime classpath enters the native image.",
            providers = [[JavaInfo]],
        ),
        "main_class": attr.string(
            doc = "Fully qualified main class.",
            mandatory = True,
        ),
        "native_image_opts": attr.string_list(
            doc = "Extra flags appended to the native-image invocation.",
        ),
    },
    toolchains = [TOOLCHAIN_TYPE],
    executable = True,
)
