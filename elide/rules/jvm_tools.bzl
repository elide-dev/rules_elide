# SPDX-License-Identifier: Apache-2.0

"""Documentation, archives, bytecode reports, and C binding generation with Elide."""

load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("//elide/private:compile_common.bzl", "TOOLCHAIN_TYPE", "compile_classpath", "runtime_classpath")

_ENV = {"ELIDE_BAZEL": "1", "SOURCE_DATE_EPOCH": "315532800"}
_DATE = "1980-01-01T00:00:02Z"

def _args(ctx, command):
    args = ctx.actions.args()
    args.add_all(["--no-env", "--no-properties", command])
    return args

def _run(ctx, mnemonic, args, inputs, outputs):
    elide = ctx.toolchains[TOOLCHAIN_TYPE].elide_info
    ctx.actions.run(
        executable = elide.binary,
        arguments = [args],
        inputs = depset(inputs, transitive = [elide.compile_tool_files]),
        outputs = outputs,
        mnemonic = mnemonic,
        env = _ENV,
    )

def _pack_tree(ctx, tree, output):
    args = _args(ctx, "jar")
    args.add_all(["--", "--create", "--date=" + _DATE, "--file"])
    args.add(output)
    args.add_all(["-C", tree.path, "."])
    _run(ctx, "ElideJar", args, [tree], [output])

def _javadoc_impl(ctx):
    html = ctx.actions.declare_directory(ctx.label.name + "_html")
    cp = compile_classpath(ctx.attr.deps)
    doclet_cp = runtime_classpath(ctx.attr.doclet_deps, [])
    args = _args(ctx, "javadoc")
    args.add("--theme", ctx.attr.theme)
    args.add("--")
    args.add("-d", html.path)
    if not ctx.attr.doclet:
        args.add("-notimestamp")
    args.add_joined("-classpath", cp, join_with = ctx.configuration.host_path_separator)
    if ctx.attr.doclet:
        args.add("-doclet", ctx.attr.doclet)
    if ctx.attr.doclet_deps:
        args.add_joined("-docletpath", doclet_cp, join_with = ctx.configuration.host_path_separator)
    args.add_all(ctx.attr.opts)
    args.add_all(ctx.files.srcs)
    _run(ctx, "ElideJavadoc", args, ctx.files.srcs + ctx.files.data + cp.to_list() + doclet_cp.to_list(), [html])
    jars = []
    if ctx.attr.jar:
        jar = ctx.actions.declare_file(ctx.label.name + "-javadoc.jar")
        _pack_tree(ctx, html, jar)
        jars.append(jar)
    return [
        DefaultInfo(files = depset([html] + jars)),
        OutputGroupInfo(html = depset([html]), javadoc_jar = depset(jars)),
    ]

elide_javadoc = rule(
    implementation = _javadoc_impl,
    attrs = {
        "data": attr.label_list(allow_files = True, doc = "Declared doclet resources and offline link metadata."),
        "deps": attr.label_list(providers = [JavaInfo], doc = "Compile classpath for documented sources."),
        "doclet": attr.string(doc = "Optional custom doclet class."),
        "doclet_deps": attr.label_list(providers = [JavaInfo], cfg = "exec", doc = "Custom doclet runtime dependencies."),
        "jar": attr.bool(default = True, doc = "Also produce a reproducible -javadoc.jar."),
        "opts": attr.string_list(doc = "Additional javadoc options; declare referenced files in data."),
        "srcs": attr.label_list(allow_files = [".java"], mandatory = True, doc = "Java source files to document."),
        "theme": attr.string(default = "default", values = ["default", "elide"]),
    },
    toolchains = [TOOLCHAIN_TYPE],
)

def _jar_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name + ".jar")
    args = _args(ctx, "jar")
    args.add_all(["--", "--create", "--date=" + _DATE, "--file"])
    args.add(output)
    if ctx.file.manifest:
        args.add("--manifest", ctx.file.manifest)
    if ctx.attr.main_class:
        args.add("--main-class", ctx.attr.main_class)
    seen = {}
    prefix = ctx.attr.strip_prefix.rstrip("/")
    for file in sorted(ctx.files.srcs, key = _file_path):
        if file.is_directory:
            args.add_all(["-C", file.path, "."])
            continue
        entry = file.short_path
        if prefix:
            if not entry.startswith(prefix + "/"):
                fail("{} is not under strip_prefix {}".format(entry, prefix))
            entry = entry[len(prefix) + 1:]
        if entry.startswith("../"):
            fail("External files require strip_prefix or a directory artifact: " + file.short_path)
        if entry in seen:
            fail("Duplicate jar entry: " + entry)
        seen[entry] = True
        root = file.path[:-len(entry)].rstrip("/") or "."
        args.add_all(["-C", root, entry])
    _run(ctx, "ElideJar", args, ctx.files.srcs + ([ctx.file.manifest] if ctx.file.manifest else []), [output])
    return [DefaultInfo(files = depset([output]))]

def _file_path(file):
    return file.path

elide_jar = rule(
    implementation = _jar_impl,
    attrs = {
        "main_class": attr.string(),
        "manifest": attr.label(allow_single_file = True),
        "srcs": attr.label_list(allow_files = True, mandatory = True, doc = "Files or directory artifacts to archive; input jars are stored, not merged."),
        "strip_prefix": attr.string(doc = "Prefix removed from workspace-relative file paths. Directory contents are stored at the archive root."),
    },
    toolchains = [TOOLCHAIN_TYPE],
)

def _report_impl(ctx):
    command = ctx.attr._command
    output = ctx.actions.declare_file(ctx.label.name + ".txt")
    elide = ctx.toolchains[TOOLCHAIN_TYPE].elide_info
    cp = runtime_classpath(ctx.attr.deps, [])
    args = _args(ctx, command)
    args.add("--")
    args.add_joined("-classpath", cp, join_with = ctx.configuration.host_path_separator)
    args.add_all(ctx.attr.opts)
    args.add_all(ctx.attr.classes if command == "javap" else ctx.files.srcs)
    if command == "javap" and not ctx.attr.classes:
        fail("elide_javap requires at least one class name")
    if command == "jdeps" and not ctx.files.srcs:
        fail("elide_jdeps requires at least one jar or class file")
    ctx.actions.run_shell(
        command = 'tool="$1"; report="$2"; shift 2; "$tool" "$@" > "$report"',
        arguments = [elide.binary.path, output.path, args],
        inputs = depset(ctx.files.srcs + ctx.files.data, transitive = [cp, elide.compile_tool_files]),
        outputs = [output],
        mnemonic = "ElideJavap" if command == "javap" else "ElideJdeps",
        env = _ENV,
    )
    return [DefaultInfo(files = depset([output]))]

_REPORT_ATTRS = {
    "classes": attr.string_list(doc = "Fully qualified classes to inspect with javap."),
    "data": attr.label_list(allow_files = True),
    "deps": attr.label_list(providers = [JavaInfo], doc = "Runtime classpath used to resolve classes."),
    "opts": attr.string_list(),
    "srcs": attr.label_list(allow_files = [".jar", ".class"], doc = "Jars or class files to analyze with jdeps."),
}

elide_jdeps = rule(
    implementation = _report_impl,
    attrs = dict(_REPORT_ATTRS, _command = attr.string(default = "jdeps")),
    toolchains = [TOOLCHAIN_TYPE],
)

elide_javap = rule(
    implementation = _report_impl,
    attrs = dict(_REPORT_ATTRS, _command = attr.string(default = "javap")),
    toolchains = [TOOLCHAIN_TYPE],
)

def _jextract_impl(ctx):
    sources = ctx.actions.declare_directory(ctx.label.name + "_sources")
    srcjar = ctx.actions.declare_file(ctx.label.name + ".srcjar")
    args = _args(ctx, "jextract")
    args.add_all(["--", "--output", sources.path])
    if ctx.attr.package:
        args.add("--target-package", ctx.attr.package)
    if ctx.attr.header_class:
        args.add("--header-class-name", ctx.attr.header_class)
    for directory in depset([f.dirname for f in ctx.files.hdrs + ctx.files.srcs] + ctx.attr.includes).to_list():
        args.add("-I", directory)
    for define in ctx.attr.defines:
        args.add("-D", define)
    args.add_all(ctx.attr.opts)
    args.add_all(ctx.files.srcs)
    _run(ctx, "ElideJextract", args, ctx.files.srcs + ctx.files.hdrs + ctx.files.data, [sources])
    _pack_tree(ctx, sources, srcjar)
    return [DefaultInfo(files = depset([srcjar])), OutputGroupInfo(sources = depset([sources]))]

elide_jextract = rule(
    implementation = _jextract_impl,
    attrs = {
        "data": attr.label_list(allow_files = True),
        "defines": attr.string_list(doc = "Preprocessor definitions, NAME or NAME=VALUE."),
        "hdrs": attr.label_list(allow_files = True, doc = "Transitive included headers; their directories are added to the include path."),
        "header_class": attr.string(doc = "Generated header class name."),
        "includes": attr.string_list(doc = "Additional execroot-relative include directories; declare all files in hdrs/data."),
        "opts": attr.string_list(doc = "Additional jextract options, such as symbol filters and library names."),
        "package": attr.string(doc = "Generated Java package."),
        "srcs": attr.label_list(allow_files = [".h"], mandatory = True, doc = "Entry-point C headers."),
    },
    toolchains = [TOOLCHAIN_TYPE],
)
