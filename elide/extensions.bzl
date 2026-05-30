"""Bzlmod module extension wiring the elide toolchain into a consumer build."""

load("//elide/private:download.bzl", "elide_download")
load("//elide/private:hub.bzl", "elide_toolchains_hub")
load("//elide/private:versions.bzl", "ELIDE_VERSIONS", "PLATFORMS")

_install = tag_class(
    attrs = {
        "repo_prefix": attr.string(
            default = "elide",
            doc = "Prefix used to name per-platform download repos.",
        ),
        "url_template": attr.string(
            doc = "Override release URL template. Tokens: {version}, {os}, {cpu}, {ext}.",
        ),
        "version": attr.string(
            doc = "Elide release version to pin (without leading 'v').",
            mandatory = True,
        ),
    },
)

def _max_version(versions):
    # String-sort is sufficient when all consumers pin to a single release.
    # SemVer-aware comparison can be added when multi-version graphs appear.
    return sorted(versions)[-1]

def _elide_impl(ctx):
    versions = []
    repo_prefix = "elide"
    url_template = ""
    for mod in ctx.modules:
        for tag in mod.tags.install:
            versions.append(tag.version)
            if mod.is_root:
                repo_prefix = tag.repo_prefix
                url_template = tag.url_template
    if not versions:
        elide_toolchains_hub(name = "elide_toolchains", version = "", repo_prefix = repo_prefix)
        return ctx.extension_metadata(reproducible = True)

    version = _max_version(versions)
    integrity_for_version = ELIDE_VERSIONS.get(version)
    if integrity_for_version == None:
        fail(
            ("Unknown elide version {!r}. Pin a release recorded in " +
             "elide/private/versions.bzl, or contribute a new entry.").format(version),
        )
    for (os, cpu) in PLATFORMS:
        integrity = integrity_for_version.get((os, cpu))
        if integrity == None:
            continue
        elide_download(
            name = repo_prefix + "_{os}_{cpu}".format(os = os, cpu = cpu),
            version = version,
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
