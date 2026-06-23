# SPDX-License-Identifier: Apache-2.0

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
    binary = "@{repo}//:bin/elide{bin_ext}",
    compile_tool_files = ["@{repo}//:elide_compile_files"],
    kotlin_stdlib = ["@{repo}//:kotlin_stdlib_jars"],
    tool_files = ["@{repo}//:elide_native_image_files"],
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

    # Register a toolchain only for platforms that actually have a repo. Defaults
    # to all PLATFORMS (the pinned `install` path materializes all four); the
    # `use` path passes just the platforms it created (a BYO subset, or a single
    # host-only local override), keeping `//:all` resolvable.
    plats = ctx.attr.platforms or ["{os}_{cpu}".format(os = o, cpu = c) for (o, c) in PLATFORMS]
    for p in plats:
        os, cpu = p.split("_", 1)
        parts.append(_TOOLCHAIN_TEMPLATE.format(
            name = p,
            repo = ctx.attr.repo_prefix + "_" + p,
            version = ctx.attr.version,
            os_constraint = OS_CONSTRAINTS[os],
            cpu_constraint = CPU_CONSTRAINTS[cpu],
            bin_ext = ".exe" if os == "windows" else "",
        ))
    ctx.file("BUILD.bazel", "".join(parts))

elide_toolchains_hub = repository_rule(
    implementation = _elide_toolchains_hub_impl,
    attrs = {
        "platforms": attr.string_list(
            default = [],
            doc = "`<os>_<cpu>` keys to register toolchains for. Empty = all PLATFORMS.",
        ),
        "repo_prefix": attr.string(
            default = "elide",
            doc = "Prefix used to name per-platform download repos.",
        ),
        "version": attr.string(mandatory = True),
    },
)
