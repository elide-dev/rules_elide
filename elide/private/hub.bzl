"""Repository rule aggregating per-platform elide toolchains under one repo."""

load(":versions.bzl", "CPU_CONSTRAINTS", "OS_CONSTRAINTS", "PLATFORMS")

visibility(["//elide/...", "//tests/..."])

_BUILD_HEADER = """\
load("@rules_elide//elide:toolchain.bzl", "elide_toolchain")

package(default_visibility = ["//visibility:public"])

"""

_TOOLCHAIN_TEMPLATE = """\
elide_toolchain(
    name = "{name}_impl",
    binary = "@{repo}//:elide_bin",
    version = "{version}",
)

toolchain(
    name = "{name}",
    exec_compatible_with = [
        "{os_constraint}",
        "{cpu_constraint}",
    ],
    target_compatible_with = [
        "{os_constraint}",
        "{cpu_constraint}",
    ],
    toolchain = ":{name}_impl",
    toolchain_type = "@rules_elide//elide:toolchain_type",
)

"""

def _elide_toolchains_hub_impl(ctx):
    parts = [_BUILD_HEADER]
    for (os, cpu) in PLATFORMS:
        parts.append(_TOOLCHAIN_TEMPLATE.format(
            name = "{os}_{cpu}".format(os = os, cpu = cpu),
            repo = ctx.attr.repo_prefix + "_{os}_{cpu}".format(os = os, cpu = cpu),
            version = ctx.attr.version,
            os_constraint = OS_CONSTRAINTS[os],
            cpu_constraint = CPU_CONSTRAINTS[cpu],
        ))
    ctx.file("BUILD.bazel", "".join(parts))

elide_toolchains_hub = repository_rule(
    implementation = _elide_toolchains_hub_impl,
    attrs = {
        "repo_prefix": attr.string(
            default = "elide",
            doc = "Prefix used to name per-platform download repos.",
        ),
        "version": attr.string(mandatory = True),
    },
)
