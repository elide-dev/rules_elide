"""The elide_toolchain rule wraps a concrete elide binary as a Bazel toolchain."""

load(":providers.bzl", "ElideToolchainInfo")

def _elide_toolchain_impl(ctx):
    tool_files = depset(
        direct = [ctx.executable.binary],
        transitive = [depset(ctx.files.tool_files)],
    )
    return [platform_common.ToolchainInfo(
        elide_info = ElideToolchainInfo(
            binary = ctx.executable.binary,
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
        "version": attr.string(
            doc = "Semantic version of the elide binary.",
            mandatory = True,
        ),
        "tool_files": attr.label_list(
            doc = "Additional runfiles required by the elide binary at action time.",
            allow_files = True,
        ),
    },
    provides = [platform_common.ToolchainInfo],
)
