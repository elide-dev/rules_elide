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

    # The Elide distribution bundles a full GraalVM (lib/truffle, lib/svm, ...),
    # so JAVA_HOME for `native-image` is the root of the extracted elide repo
    # (i.e. parent of bin/elide).
    elide_home = elide.binary.dirname
    if elide_home.endswith("/bin"):
        elide_home = elide_home[:-len("/bin")]

    args = ctx.actions.args()
    args.add("native-image")
    args.add("--")
    args.add("--no-fallback")
    args.add_joined("-classpath", classpath, join_with = sep)
    args.add("-H:Path=" + output.dirname)
    args.add("-H:Name=" + output.basename)
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
        env = {"JAVA_HOME": elide_home},
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
