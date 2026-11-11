# SPDX-License-Identifier: Apache-2.0

"""Repository rule that downloads one elide release artifact for one platform."""

load(":versions.bzl", "binary_ext", "download_url", "python_download_url")

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

# The elide binary with its distribution as runfiles: pass this (not the bare
# `{binary_path}` file) wherever elide runs as a tool outside the toolchain,
# e.g. `register_elide_kotlin_toolchain(elide = ...)`. The executable stays the
# real `{binary_path}`, so elide still resolves its home from its own path, and
# remote executors receive lib/ and conf/ alongside it. A bare file has no
# runfiles: `elide java` then fails with "Error loading java.security file".
filegroup(
    name = "elide",
    srcs = ["{binary_path}"],
    data = [":elide_compile_files"],
)

# Minimal input set for JVM compile actions (elide javac, kotlinc, jar, and
# `elide java`, which loads conf/security/java.security from its home).
# Excludes: doc/ (HTML docs), lib/svm/ + lib/truffle/ + lib/static/ (native-image),
#           lib/llvm/ + lib/resources/jextract/ (C tools), Python runtime, Maven.
filegroup(
    name = "elide_compile_files",
    srcs = glob(
        ["bin/**", "conf/**", "lib/**"],
        exclude = [
            # Component markers (e.g. Python's) stay with their own filegroups.
            "conf/components/**",
            "lib/llvm/**",
            "lib/resources/jextract/**",
            "lib/static/**",
            "lib/svm/**",
            "lib/truffle/**",
            "lib/resources/python/**",
            "lib/maven/**",
        ],
    ),
)

# C binding generation retains LLVM without burdening every JVM compiler action.
filegroup(
    name = "elide_jextract_files",
    srcs = [":elide_compile_files"] + glob(["lib/llvm/**", "lib/resources/jextract/**"]),
)

# Bundled LLVM C toolchain (clang driver, lld, compiler-rt/libc++/libunwind,
# clang resource headers, and the glibc sysroot) for elide_cc_binary. The
# target-prefixed driver auto-loads its sibling <triple>.cfg, which selects the
# sysroot, lld, compiler-rt, and libunwind, so no host compiler, headers, or
# libraries are consulted. Empty on distributions without lib/llvm/toolchain.
filegroup(
    name = "elide_cc_compiler",
    srcs = glob(
        ["lib/llvm/toolchain/bin/*-unknown-linux-gnu-clang"],
        allow_empty = True,
    ),
)

filegroup(
    name = "elide_cc_files",
    srcs = glob(
        [
            "lib/llvm/toolchain/bin/*-unknown-linux-gnu-clang",
            "lib/llvm/toolchain/bin/*-unknown-linux-gnu.cfg",
            "lib/llvm/toolchain/bin/ld.lld",
            "lib/llvm/toolchain/lib/clang/**",
            "lib/llvm/toolchain/lib/*-unknown-linux-gnu/**",
            "lib/llvm/toolchain/sysroot/*-unknown-linux-gnu/**",
        ],
        allow_empty = True,
    ),
)

# Full tool set for elide native-image: compile files + GraalVM SVM + C headers.
# Excludes only the clearly irrelevant: doc/, Python runtime, Maven tools.
filegroup(
    name = "elide_native_image_files",
    srcs = glob(
        ["bin/**", "lib/**", "conf/**", "include/**"],
        exclude = [
            "lib/resources/python/**",
            "lib/maven/**",
        ],
    ),
)

# Runtime inputs for Python-capable actions, including the component marker.
# Kept separate so JVM compilation does not ship the Python standard library.
filegroup(
    name = "elide_python_files",
    srcs = glob(["bin/**", "lib/**", "conf/**"]),
)

filegroup(
    name = "kotlin_stdlib_jars",
    srcs = glob(["lib/resources/kotlin/*/lib/kotlin-stdlib.jar"]),
)
"""

def _chmod_tool(ctx):
    # Repository rules see the client PATH, which may be minimal (e.g. builds
    # that deliberately hide host compilers). Fall back to standard locations.
    chmod = ctx.which("chmod")
    if chmod:
        return chmod
    for candidate in ["/bin/chmod", "/usr/bin/chmod"]:
        if ctx.path(candidate).exists:
            return ctx.path(candidate)
    fail("rules_elide: chmod is required to restore executable bits in the Elide distribution, but was not found on PATH, /bin, or /usr/bin")

def _make_executable(ctx, chmod, paths, required = False):
    # Missing optional wrappers (they differ between releases) are tolerated;
    # required tools, such as the bundled LLVM binaries, must be fixed.
    result = ctx.execute([chmod, "+x"] + paths)
    if required and result.return_code != 0:
        fail("rules_elide: chmod +x failed for {}: {}".format(paths, result.stderr))

def _elide_download_impl(ctx):
    os = ctx.attr.os
    cpu = ctx.attr.cpu
    url = download_url(ctx.attr.url_template, ctx.attr.channel, ctx.attr.version, os, cpu)
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

    # Apply the matching overlay after the base: it replaces bin/elide and
    # supplies Python resources and conf/components/python in the same tree.
    if ctx.attr.python_integrity:
        ctx.download_and_extract(
            url = python_download_url(ctx.attr.python_url_template, ctx.attr.channel, ctx.attr.version, os, cpu),
            integrity = ctx.attr.python_integrity,
            canonical_id = "elide-python-{}-{}-{}".format(ctx.attr.version, os, cpu),
        )

    # Wrapper scripts under bin/ (java, javac, kotlinc, ...) ship without an
    # exec bit in the CDN archive; restore it so consumers (notably the
    # `elide native-image` JAVA_HOME probe) can invoke them.
    if os != "windows":
        chmod = _chmod_tool(ctx)
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
            _make_executable(ctx, chmod, ["bin/" + name])
        for name in ["native-image", "native-image-configure"]:
            _make_executable(ctx, chmod, ["lib/svm/bin/" + name])

        # The JDK's process launcher helper also lacks it; without it every
        # subprocess started from `elide java` fails with posix_spawn EACCES.
        _make_executable(ctx, chmod, ["lib/jspawnhelper"])

        # The bundled LLVM toolchain ships its multicall aliases (clang,
        # <triple>-clang, ld.lld, llvm-ranlib, ...) as full copies without an
        # exec bit (observed in the 1.6.3 linux-amd64 archive); only clang-<N>,
        # lld, and a few others are executable. Restore it for every binary.
        llvm_bin = ctx.path("lib/llvm/toolchain/bin")
        if llvm_bin.exists:
            _make_executable(ctx, chmod, [
                str(entry)
                for entry in llvm_bin.readdir()
                if not entry.basename.endswith(".cfg")
            ])
    bin_ext = binary_ext(os)
    binary_path = ctx.attr.binary_path or ("bin/elide" + bin_ext)
    ctx.file("BUILD.bazel", _BUILD_TEMPLATE.format(
        binary_path = binary_path,
        bin_ext = bin_ext,
    ))

def _elide_local_impl(ctx):
    src = ctx.path(ctx.attr.local_path)
    if not src.exists:
        fail(
            "elide.use(local_path = ...) points at a path that does not exist: {}\n".format(ctx.attr.local_path) +
            "It must be an already-extracted Elide distribution directory (containing bin/elide, lib/, ...).",
        )

    # Surface each top-level entry of the local distribution at the repo root so
    # the BUILD globs (bin/**, lib/**, include/**) and `bin/elide` resolve, exactly
    # as for a downloaded+extracted archive — but without copying or downloading.
    for child in src.readdir():
        ctx.symlink(child, child.basename)

    bin_ext = binary_ext(ctx.attr.os)
    binary_path = ctx.attr.binary_path or ("bin/elide" + bin_ext)
    ctx.file("BUILD.bazel", _BUILD_TEMPLATE.format(
        binary_path = binary_path,
        bin_ext = bin_ext,
    ))

# Wires a locally-extracted Elide distribution as a toolchain repo (no download).
# `local = True`: re-evaluated each build so edits to the distribution are picked
# up. Used by `elide.use(local_path = ...)` for fast local iteration.
elide_local = repository_rule(
    implementation = _elide_local_impl,
    local = True,
    attrs = {
        "binary_path": attr.string(
            doc = "Path to the elide executable within the distribution. " +
                  "Defaults to bin/elide(.exe on windows).",
        ),
        "local_path": attr.string(
            mandatory = True,
            doc = "Absolute path to an already-extracted Elide distribution directory.",
        ),
        "os": attr.string(mandatory = True),
    },
)

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
        "python_integrity": attr.string(
            doc = "SRI for the matching Python overlay; empty disables the overlay.",
        ),
        "python_url_template": attr.string(
            doc = "Optional Python overlay URL template; same tokens as url_template.",
        ),
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
