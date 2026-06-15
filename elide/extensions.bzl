# SPDX-License-Identifier: Apache-2.0

"""Bzlmod module extension wiring the elide toolchain into a consumer build."""

load("//elide/private:download.bzl", "elide_download", "elide_local")
load("//elide/private:hub.bzl", "elide_toolchains_hub")
load("//elide/private:versions.bzl", "DEFAULT_CHANNEL", "DEFAULT_VERSION", "ELIDE_VERSIONS", "PLATFORMS")

# `elide.use` — bring-your-own Elide: a custom release (your own tarballs + hashes
# via `version` + `url_template` + `integrity`), or a locally-extracted
# distribution (`local_path`, no download). Overrides `elide.install` when present
# in the root module. Lets you test against a custom/local Elide build without
# waiting for it to land in elide/private/versions.bzl.
_use = tag_class(
    attrs = {
        "channel": attr.string(
            default = DEFAULT_CHANNEL,
            doc = "Release channel token for `url_template`. Default nightly.",
        ),
        "integrity": attr.string_dict(
            doc = "Per-platform SRI for a BYO release: keys `<os>_<cpu>` " +
                  "(e.g. `linux_amd64`) -> `sha256-<base64>`. Required together " +
                  "with `url_template`; ignored when `local_path` is set. Only the " +
                  "platforms listed here get a toolchain.",
        ),
        "local_path": attr.string(
            doc = "Absolute path to an already-extracted Elide distribution " +
                  "(contains bin/elide, lib/, ...). When set, the host-platform " +
                  "toolchain uses it directly with no download (build becomes " +
                  "non-reproducible); takes precedence over url_template/integrity.",
        ),
        "repo_prefix": attr.string(
            default = "elide",
            doc = "Prefix used to name per-platform toolchain repos.",
        ),
        "url_template": attr.string(
            doc = "URL template for a BYO release. Tokens: {channel}, {version}, " +
                  "{os}, {cpu}, {ext}. May be a file:// URL.",
        ),
        "version": attr.string(
            doc = "Version tag for the BYO release; used in URLs and as the " +
                  "toolchain version label. Need not appear in versions.bzl.",
        ),
    },
)

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

def _host_platform(ctx):
    """Maps the host (os.name, os.arch) to an (os, cpu) pair, or (None, None)."""
    name = ctx.os.name.lower()
    arch = ctx.os.arch.lower()
    os = None
    if "linux" in name:
        os = "linux"
    elif "mac" in name or "darwin" in name or "osx" in name:
        os = "macos"
    elif "windows" in name:
        os = "windows"
    cpu = None
    if arch in ("amd64", "x86_64", "x64"):
        cpu = "amd64"
    elif arch in ("aarch64", "arm64"):
        cpu = "arm64"
    return os, cpu

def _wire_use(ctx, t):
    """Wires the toolchain from a root `elide.use` tag (BYO release or local dir)."""
    prefix = t.repo_prefix
    if t.local_path:
        os, cpu = _host_platform(ctx)
        if os == None or cpu == None:
            fail("elide.use(local_path) could not map host os.name={}, os.arch={} to a supported platform.".format(
                ctx.os.name,
                ctx.os.arch,
            ))
        key = "{}_{}".format(os, cpu)
        elide_local(name = "{}_{}".format(prefix, key), local_path = t.local_path, os = os)
        elide_toolchains_hub(
            name = "elide_toolchains",
            version = t.version or "local",
            repo_prefix = prefix,
            platforms = [key],
        )

        # A local path is machine-specific; the resulting build is not reproducible.
        return ctx.extension_metadata(reproducible = False)

    if not t.url_template or not t.integrity:
        fail("elide.use requires either `local_path`, or `url_template` together with " +
             "`integrity` (per-platform `<os>_<cpu>` -> SRI hashes).")
    plats = []
    for key in t.integrity:
        os, cpu = key.split("_", 1)
        elide_download(
            name = "{}_{}".format(prefix, key),
            version = t.version,
            channel = t.channel,
            os = os,
            cpu = cpu,
            integrity = t.integrity[key],
            url_template = t.url_template,
        )
        plats.append(key)
    elide_toolchains_hub(
        name = "elide_toolchains",
        version = t.version or "custom",
        repo_prefix = prefix,
        platforms = plats,
    )
    return ctx.extension_metadata(reproducible = True)

def _elide_impl(ctx):
    versions = []
    channel = DEFAULT_CHANNEL
    repo_prefix = "elide"
    url_template = ""
    use_tag = None
    for mod in ctx.modules:
        for tag in mod.tags.install:
            versions.append(tag.version)
            if mod.is_root:
                channel = tag.channel
                repo_prefix = tag.repo_prefix
                url_template = tag.url_template
        if mod.is_root:
            for tag in mod.tags.use:
                use_tag = tag  # last root `use` wins

    # A root `elide.use` (BYO release or local distribution) overrides `install`.
    if use_tag != None:
        return _wire_use(ctx, use_tag)

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
    tag_classes = {"install": _install, "use": _use},
)
