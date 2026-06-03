# SPDX-License-Identifier: Apache-2.0

"""Repository rule that downloads one elide release artifact for one platform."""

load(":versions.bzl", "DEFAULT_CHANNEL", "DEFAULT_URL_TEMPLATE", "archive_ext", "binary_ext")

visibility(["//elide/...", "//tests/..."])

# Generated BUILD.bazel for the per-platform download repo.
# - `elide_files` carries the full extracted distribution as runfiles so that
#   actions invoking `:elide_bin` see sibling resources (`resources/`, jars, etc.).
# - `elide_bin` is the wrapped executable target.
_BUILD_TEMPLATE = """\
package(default_visibility = ["//visibility:public"])

# Export bin/elide as the canonical executable label. The toolchain rule
# accepts it directly as `binary = ...` via attr.label(executable=True,
# allow_files=True) — no rename, so its dirname points at the real bin/
# inside the extracted distribution and JAVA_HOME = parent of bin/ resolves
# `<JAVA_HOME>/bin/java` (and friends) as native-image expects.
exports_files(["{binary_path}"])

# Minimal input set for JVM compile actions (elide javac, kotlinc, jar).
# Excludes: doc/ (HTML docs), lib/svm/ + lib/truffle/ (native-image only),
#           lib/resources/python/ (Python runtime), lib/maven/ (Maven tools).
filegroup(
    name = "elide_compile_files",
    srcs = glob(
        ["bin/**", "lib/**"],
        exclude = [
            "lib/svm/**",
            "lib/truffle/**",
            "lib/resources/python/**",
            "lib/maven/**",
        ],
    ),
)

# Full tool set for elide native-image: compile files + GraalVM SVM + C headers.
# Excludes only the clearly irrelevant: doc/, Python runtime, Maven tools.
filegroup(
    name = "elide_native_image_files",
    srcs = glob(
        ["bin/**", "lib/**", "include/**"],
        exclude = [
            "lib/resources/python/**",
            "lib/maven/**",
        ],
    ),
)

filegroup(
    name = "kotlin_stdlib_jars",
    srcs = glob(["lib/resources/kotlin/*/lib/kotlin-stdlib.jar"]),
)
"""

def _elide_download_impl(ctx):
    os = ctx.attr.os
    cpu = ctx.attr.cpu
    url = (ctx.attr.url_template or DEFAULT_URL_TEMPLATE).format(
        channel = ctx.attr.channel or DEFAULT_CHANNEL,
        version = ctx.attr.version,
        os = os,
        cpu = cpu,
        ext = archive_ext(os),
    )
    ctx.download_and_extract(
        url = url,
        integrity = ctx.attr.integrity,
        stripPrefix = ctx.attr.strip_prefix,
        canonical_id = "elide-{version}-{os}-{cpu}".format(
            version = ctx.attr.version,
            os = os,
            cpu = cpu,
        ),
    )

    # Wrapper scripts under bin/ (java, javac, kotlinc, ...) ship without an
    # exec bit in the CDN archive; restore it so consumers (notably the
    # `elide native-image` JAVA_HOME probe) can invoke them.
    if os != "windows":
        for name in [
            "elide",
            "google-java-format",
            "jar",
            "java",
            "javac",
            "javadoc",
            "javap",
            "kotlinc",
            "ktfmt",
        ]:
            ctx.execute(["chmod", "+x", "bin/" + name])
        for name in ["native-image", "native-image-configure"]:
            ctx.execute(["chmod", "+x", "lib/svm/bin/" + name])
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
        "channel": attr.string(
            doc = "Release channel: nightly, preview, or release. Defaults to the " +
                  "value of DEFAULT_CHANNEL in versions.bzl.",
        ),
        "cpu": attr.string(mandatory = True),
        "integrity": attr.string(mandatory = True),
        "os": attr.string(mandatory = True),
        "strip_prefix": attr.string(
            default = "",
            doc = "Top-level archive directory to strip. Default empty (CDN " +
                  "artifacts unpack directly to bin/, resources/, ...).",
        ),
        "url_template": attr.string(
            doc = "Override release URL. Tokens: {channel}, {version}, {os}, {cpu}, {ext}.",
        ),
        "version": attr.string(mandatory = True),
    },
)
