# SPDX-License-Identifier: Apache-2.0

"""Bzlmod module extension wiring the elide toolchain into a consumer build."""

load("//elide/private:download.bzl", "elide_download")
load("//elide/private:hub.bzl", "elide_toolchains_hub")
load("//elide/private:versions.bzl", "DEFAULT_CHANNEL", "DEFAULT_VERSION", "ELIDE_VERSIONS", "PLATFORMS")

_install = tag_class(
    attrs = {
        "channel": attr.string(
            default = DEFAULT_CHANNEL,
            doc = "Release channel: nightly, preview, or release.",
        ),
        "repo_prefix": attr.string(
            default = "elide",
            doc = "Prefix used to name per-platform download repos.",
        ),
        "url_template": attr.string(
            doc = "Override release URL template. Tokens: {channel}, {version}, " +
                  "{os}, {cpu}, {ext}.",
        ),
        "version": attr.string(
            default = DEFAULT_VERSION,
            doc = "Elide release version tag, e.g. `1.2.0+20260602`. " +
                  "Must match an entry in elide/private/versions.bzl. " +
                  "Defaults to the most-recently verified release.",
        ),
    },
)

def _parse_semver(version):
    """Parses `X.Y.Z` (with optional `+metadata`) into a comparable tuple.

    Non-numeric or short versions sort lexically after numeric ones; this gives
    `1.10.0` > `1.9.0` while still keeping `latest` predictably greatest.
    """
    if version == "latest":
        return (999999999, 0, 0, "")
    core = version.split("+", 1)[0].split("-", 1)[0]
    parts = core.split(".")
    nums = []
    for p in parts:
        if p.isdigit():
            nums.append(int(p))
        else:
            return (-1, 0, 0, version)
    if len(nums) < 3:
        nums = nums + [0] * (3 - len(nums))
    return (nums[0], nums[1], nums[2], version)

def _select_version(versions):
    return sorted(versions, key = _parse_semver)[-1]

def _elide_impl(ctx):
    versions = []
    channel = DEFAULT_CHANNEL
    repo_prefix = "elide"
    url_template = ""
    for mod in ctx.modules:
        for tag in mod.tags.install:
            versions.append(tag.version)
            if mod.is_root:
                channel = tag.channel
                repo_prefix = tag.repo_prefix
                url_template = tag.url_template
    if not versions:
        elide_toolchains_hub(name = "elide_toolchains", version = "", repo_prefix = repo_prefix)
        return ctx.extension_metadata(reproducible = True)

    version = _select_version(versions)
    integrity_for_version = ELIDE_VERSIONS.get(version)
    if integrity_for_version == None:
        fail(
            ("Unknown elide version '{}'. Pin a release recorded in " +
             "elide/private/versions.bzl, or contribute a new entry.").format(version),
        )
    for (os, cpu) in PLATFORMS:
        integrity = integrity_for_version.get((os, cpu))
        if integrity == None:
            continue
        elide_download(
            name = repo_prefix + "_{os}_{cpu}".format(os = os, cpu = cpu),
            version = version,
            channel = channel,
            os = os,
            cpu = cpu,
            integrity = integrity,
            url_template = url_template,
        )
    elide_toolchains_hub(
        name = "elide_toolchains",
        version = version,
        repo_prefix = repo_prefix,
    )
    return ctx.extension_metadata(reproducible = True)

elide = module_extension(
    implementation = _elide_impl,
    tag_classes = {"install": _install},
)
