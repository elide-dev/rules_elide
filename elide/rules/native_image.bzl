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
    classpath = depset(transitive = [
        runtime_classpath(ctx.attr.deps, []),
        elide.kotlin_stdlib_jars,
    ])
    sep = ctx.configuration.host_path_separator

    elide_home = elide.binary.dirname
    if elide_home.endswith("/bin"):
        elide_home = elide_home[:-len("/bin")]

    host_java_home = ctx.configuration.default_shell_env.get("JAVA_HOME", "")
    java_home = host_java_home if host_java_home else elide_home
    path = java_home + "/bin:" + elide_home + "/lib/svm/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    args = ctx.actions.args()
    args.add_joined("-classpath", classpath, join_with = sep)
    for opt in ctx.attr.native_image_opts:
        args.add(opt)

    ctx.actions.run_shell(
        mnemonic = "ElideNativeImage",
        command = """\
EXECROOT="$(pwd)"
export JAVA_HOME="{java_home}"
export PATH="{path}"
exec "{elide_bin}" native-image -- --no-fallback "$@" -o "$EXECROOT/{output_path}" "{main_class}"
""".format(
            java_home = java_home,
            path = path,
            elide_bin = elide.binary.path,
            output_path = output.path,
            main_class = ctx.attr.main_class,
        ),
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
