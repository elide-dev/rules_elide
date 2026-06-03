# SPDX-License-Identifier: Apache-2.0

"""Native image rule for rules_elide.

`elide_native_image` runs `elide native-image` to compile JVM bytecode
(provided via JavaInfo deps) into a standalone native executable.
"""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
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

    graalvm_home = ctx.attr._graalvm_home[BuildSettingInfo].value

    args = ctx.actions.args()
    args.add_joined("-classpath", classpath, join_with = sep)
    for opt in ctx.attr.native_image_opts:
        args.add(opt)

    strip_cmd = ""

    if graalvm_home:
        # Explicit path — bake it in directly.
        java_home_setup = 'export JAVA_HOME="{}"'.format(graalvm_home)
        path = graalvm_home + "/bin:" + elide_home + "/lib/svm/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        path_expr = path
    else:
        # Fall back to JAVA_HOME / GRAALVM_HOME from the action environment.
        # Callers must pass these through via --action_env=JAVA_HOME (and/or GRAALVM_HOME)
        # since --incompatible_strict_action_env blocks env var inheritance by default.
        java_home_setup = """\
if [ -z "${JAVA_HOME:-}" ] && [ -n "${GRAALVM_HOME:-}" ]; then
  export JAVA_HOME="$GRAALVM_HOME"
fi
if [ -z "${JAVA_HOME:-}" ]; then
  echo "error: JAVA_HOME is not set and --@rules_elide//elide:graalvm_home was not provided." >&2
  echo "  Set JAVA_HOME in your environment and add to .bazelrc: build --action_env=JAVA_HOME" >&2
  echo "  Or set the build flag directly:  build --@rules_elide//elide:graalvm_home=/path/to/graalvm" >&2
  exit 1
fi"""
        path_expr = "$JAVA_HOME/bin:{elide_home}/lib/svm/bin:/usr/bin:/bin:/usr/sbin:/sbin".format(
            elide_home = elide_home,
        )

    ctx.actions.run_shell(
        mnemonic = "ElideNativeImage",
        command = """\
EXECROOT="$(pwd)"
export SOURCE_DATE_EPOCH=0
{java_home_setup}
export PATH="{path_expr}"
"{elide_bin}" native-image -- --no-fallback "$@" -o "$EXECROOT/{output_path}" "{main_class}" || exit $?
{strip_cmd}""".format(
            java_home_setup = java_home_setup,
            path_expr = path_expr,
            elide_bin = elide.binary.path,
            output_path = output.path,
            main_class = ctx.attr.main_class,
            strip_cmd = strip_cmd,
        ),
        arguments = [args],
        inputs = depset(transitive = [classpath, elide.tool_files]),
        outputs = [output],
        use_default_shell_env = True,
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
        "_graalvm_home": attr.label(
            default = "@rules_elide//elide:graalvm_home",
            providers = [BuildSettingInfo],
        ),
    },
    toolchains = [TOOLCHAIN_TYPE],
    executable = True,
)
