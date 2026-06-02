# SPDX-License-Identifier: Apache-2.0

"""The elide_toolchain rule wraps a concrete elide binary as a Bazel toolchain."""

load(":providers.bzl", "ElideToolchainInfo")

def _elide_toolchain_impl(ctx):
    tool_files = depset(
        direct = [ctx.executable.binary],
        transitive = [depset(ctx.files.tool_files)],
    )
    kotlin_stdlib_jars = depset(direct = ctx.files.kotlin_stdlib)
    return [platform_common.ToolchainInfo(
        elide_info = ElideToolchainInfo(
            binary = ctx.executable.binary,
            kotlin_stdlib_jars = kotlin_stdlib_jars,
            version = ctx.attr.version,
            tool_files = tool_files,
        ),
    )]

elide_toolchain = rule(
    implementation = _elide_toolchain_impl,
    attrs = {
        "binary": attr.label(
            doc = "Executable target for the elide binary.",
            mandatory = True,
            executable = True,
            cfg = "exec",
            allow_files = True,
        ),
        "kotlin_stdlib": attr.label_list(
            doc = "Kotlin stdlib jars bundled with this Elide release (from kotlin_stdlib_jars filegroup).",
            allow_files = [".jar"],
            cfg = "exec",
        ),
        "tool_files": attr.label_list(
            doc = "Additional runfiles required by the elide binary at action time.",
            allow_files = True,
            cfg = "exec",
        ),
        "version": attr.string(
            doc = "Semantic version of the elide binary.",
            mandatory = True,
        ),
    },
    provides = [platform_common.ToolchainInfo],
)
