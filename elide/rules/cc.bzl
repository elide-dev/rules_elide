# SPDX-License-Identifier: Apache-2.0

"""Hermetic C executables built with the LLVM toolchain bundled in Elide."""

load("//elide/private:compile_common.bzl", "TOOLCHAIN_TYPE")

# Keep the driver from resolving its own path through symlinks: install-dir
# lookups (target .cfg, lld, resource headers, runtimes, sysroot) then stay
# inside the action's declared inputs instead of the real external repository.
_BASE_FLAGS = ["-no-canonical-prefixes"]

def _compiler(ctx):
    elide = ctx.toolchains[TOOLCHAIN_TYPE].elide_info
    compiler = getattr(elide, "cc_compiler", None)
    if not compiler:
        fail(
            "{}: the resolved Elide toolchain has no bundled LLVM C compiler. ".format(ctx.label) +
            "elide_cc_binary needs a Linux Elide distribution that ships lib/llvm/toolchain " +
            "(wired through elide_toolchain.cc_compiler / cc_tool_files).",
        )
    return compiler, elide.cc_tool_files

def _object_path(ctx, src):
    # Mirror the source's package-relative path so same-named files in
    # different directories cannot collide.
    rel = src.short_path
    pkg = ctx.label.package
    if pkg and rel.startswith(pkg + "/"):
        rel = rel[len(pkg) + 1:]
    return "_objs/{}/{}.o".format(ctx.label.name, rel.rsplit(".", 1)[0])

def _elide_cc_binary_impl(ctx):
    compiler, tool_files = _compiler(ctx)
    headers = [f for f in ctx.files.srcs if f.extension == "h"] + ctx.files.hdrs
    sources = [f for f in ctx.files.srcs if f.extension == "c"]
    if not sources:
        fail("{}: srcs must contain at least one .c file".format(ctx.label))

    include_roots = ["."]
    if ctx.bin_dir.path not in include_roots:
        include_roots.append(ctx.bin_dir.path)

    objects = []
    for src in sources:
        obj = ctx.actions.declare_file(_object_path(ctx, src))
        args = ctx.actions.args()
        args.add_all(_BASE_FLAGS)
        args.add_all(include_roots, before_each = "-iquote")
        args.add_all(ctx.attr.defines, format_each = "-D%s")
        args.add_all(ctx.attr.copts)
        args.add_all(["-c", src])
        args.add("-o", obj)
        ctx.actions.run(
            executable = compiler,
            arguments = [args],
            inputs = depset([src] + headers, transitive = [tool_files]),
            outputs = [obj],
            mnemonic = "ElideCcCompile",
            progress_message = "Compiling C %{label} (" + src.short_path + ")",
            env = {},
        )
        objects.append(obj)

    out = ctx.actions.declare_file(ctx.label.name)
    args = ctx.actions.args()
    args.add_all(_BASE_FLAGS)
    args.add_all(objects)
    args.add_all(ctx.attr.linkopts)
    args.add("-o", out)
    ctx.actions.run(
        executable = compiler,
        arguments = [args],
        inputs = depset(objects, transitive = [tool_files]),
        outputs = [out],
        mnemonic = "ElideCcLink",
        progress_message = "Linking C %{label}",
        env = {},
    )
    return [DefaultInfo(
        executable = out,
        files = depset([out]),
        runfiles = ctx.runfiles(files = ctx.files.data),
    )]

elide_cc_binary = rule(
    implementation = _elide_cc_binary_impl,
    doc = """Compiles and links a C executable with Elide's bundled LLVM toolchain.

Each `.c` source is compiled in its own action, then linked with lld against the
distribution's glibc sysroot, compiler-rt, and libunwind. Actions use only the
toolchain's declared `cc_tool_files`, run with an empty environment, and never
consult a host compiler, headers, or libraries. Output targets the toolchain's
own Linux platform; cross-compilation and C++ are not supported.

`elide cc` itself is not used: in Elide 1.6.3 it only compiles a single
freestanding source without system headers or linking.
""",
    attrs = {
        "copts": attr.string_list(doc = "Additional compiler options, e.g. `-O2` or `-Wall`."),
        "data": attr.label_list(allow_files = True, doc = "Runtime data files."),
        "defines": attr.string_list(doc = "Preprocessor definitions, NAME or NAME=VALUE."),
        "hdrs": attr.label_list(
            allow_files = [".h"],
            doc = "Headers included by srcs. Include them by workspace-relative path.",
        ),
        "linkopts": attr.string_list(doc = "Additional linker driver options, e.g. `-lm`."),
        "srcs": attr.label_list(
            allow_files = [".c", ".h"],
            mandatory = True,
            doc = "C sources and private headers.",
        ),
    },
    executable = True,
    toolchains = [TOOLCHAIN_TYPE],
)
