"""Repository rule that downloads one elide release artifact for one platform."""

load(":versions.bzl", "DEFAULT_URL_TEMPLATE", "archive_ext", "binary_ext")

visibility(["//elide/...", "//tests/..."])

_BUILD_TEMPLATE = """\
load("@bazel_skylib//rules:native_binary.bzl", "native_binary")

package(default_visibility = ["//visibility:public"])

native_binary(
    name = "elide_bin",
    src = "{binary_path}",
    out = "elide_bin{bin_ext}",
)

filegroup(
    name = "tool_files",
    srcs = ["{binary_path}"],
)
"""

def _elide_download_impl(ctx):
    os = ctx.attr.os
    cpu = ctx.attr.cpu
    url = (ctx.attr.url_template or DEFAULT_URL_TEMPLATE).format(
        version = ctx.attr.version,
        os = os,
        cpu = cpu,
        ext = archive_ext(os),
    )
    strip_prefix = ctx.attr.strip_prefix.format(version = ctx.attr.version)
    ctx.download_and_extract(
        url = url,
        integrity = ctx.attr.integrity,
        stripPrefix = strip_prefix,
        canonical_id = "elide-{version}-{os}-{cpu}".format(
            version = ctx.attr.version,
            os = os,
            cpu = cpu,
        ),
    )
    bin_ext = binary_ext(os)
    binary_path = ctx.attr.binary_path or ("bin/elide" + bin_ext)
    ctx.file("BUILD.bazel", _BUILD_TEMPLATE.format(
        binary_path = binary_path,
        bin_ext = bin_ext,
    ))

elide_download = repository_rule(
    implementation = _elide_download_impl,
    attrs = {
        "binary_path": attr.string(
            doc = "Path to the elide executable inside the archive after strip. " +
                  "Defaults to bin/elide(.exe on windows).",
        ),
        "cpu": attr.string(mandatory = True),
        "integrity": attr.string(mandatory = True),
        "os": attr.string(mandatory = True),
        "strip_prefix": attr.string(
            default = "elide-{version}",
            doc = "Top-level archive directory to strip. Token: {version}.",
        ),
        "url_template": attr.string(
            doc = "Override release URL. Tokens: {version}, {os}, {cpu}, {ext}.",
        ),
        "version": attr.string(mandatory = True),
    },
)
