# SPDX-License-Identifier: Apache-2.0

"""API reference sites from `JavaInfo` targets, rendered by a custom doclet.

`elide_apidocs` runs javadoc once over the source jars of `deps` with a custom doclet,
[elide-dev/doclet](https://github.com/elide-dev/doclet) by default. The doclet renders through
a JavaScript runtime; the rule supplies the Elide binary from the registered Elide toolchain, so
neither Node nor Bun has to be installed.
"""

load("@rules_java//java/common:java_common.bzl", "java_common")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("//elide/private:compile_common.bzl", "TOOLCHAIN_TYPE")

_ENV = {"ELIDE_BAZEL": "1", "SOURCE_DATE_EPOCH": "315532800"}
_ELEMENT_LISTS = ("element-list", "package-list")

def _java_files(target):
    if JavaInfo in target:
        return target[JavaInfo].transitive_runtime_jars
    return depset(target.files.to_list())

def _offline_link_dir(ctx, index, url, target):
    files = target.files.to_list()
    if len(files) == 1 and files[0].is_directory:
        return files[0].path, files
    lists = [f for f in files if f.basename in _ELEMENT_LISTS]
    if len(lists) == 1:
        return lists[0].dirname, files
    if len(files) != 1:
        fail("offline_links[{}] must be one element-list file or a directory that holds one".format(url))

    # Any single file is the element-list; javadoc looks for that name in a directory.
    linked = ctx.actions.declare_file("{}_links/{}/element-list".format(ctx.label.name, index))
    ctx.actions.symlink(output = linked, target_file = files[0])
    return linked.dirname, [linked]

def _apidocs_impl(ctx):
    elide = ctx.toolchains[TOOLCHAIN_TYPE].elide_info
    runtime = ctx.attr.java_runtime[java_common.JavaRuntimeInfo]
    infos = [dep[JavaInfo] for dep in ctx.attr.deps]
    srcjars = []
    for info in infos:
        srcjars.extend(info.source_jars)
        if ctx.attr.generated_sources:
            srcjars.extend([out.generated_source_jar for out in info.java_outputs if out.generated_source_jar])
    srcjars = depset(srcjars).to_list()
    if not srcjars:
        fail("deps provide no source jars to document")
    classpath = java_common.merge(infos).transitive_compile_time_jars
    doclet = depset(transitive = [_java_files(ctx.attr.doclet)])
    sep = ctx.configuration.host_path_separator

    site = ctx.actions.declare_directory(ctx.label.name + "_site")
    archive = ctx.actions.declare_file(ctx.label.name + ".tar.gz")

    args = ctx.actions.args()
    args.use_param_file("--argfile=%s", use_always = True)
    args.set_param_file_format("multiline")
    args.add("--out", site.path)
    args.add("--archive", archive)
    args.add_all(srcjars, before_each = "--srcjar")
    args.add_all(ctx.attr.packages, before_each = "--package")
    args.add_all(ctx.attr.exclude_packages, before_each = "--exclude")
    args.add_joined("--classpath", classpath, join_with = sep, omit_if_empty = True)
    args.add("--doclet", ctx.attr.doclet_class)
    args.add_joined("--docletpath", doclet, join_with = sep)
    args.add("--")
    if ctx.attr.title:
        args.add("-doctitle", ctx.attr.title)
        args.add("-windowtitle", ctx.attr.title)
    if ctx.attr.module_name:
        args.add("--module-name", ctx.attr.module_name)
    if ctx.attr.version:
        args.add("--module-version", ctx.attr.version)
    if ctx.file.theme:
        args.add("--theme", ctx.file.theme)
    if ctx.attr.source_ref:
        args.add("--source-ref", ctx.attr.source_ref)
    if ctx.attr.problems:
        args.add("--problems", ctx.attr.problems)
    args.add_all(ctx.attr.links, before_each = "-link")
    link_files = []
    for index, (url, target) in enumerate(sorted(ctx.attr.offline_links.items())):
        path, files = _offline_link_dir(ctx, index, url, target)
        args.add_all(["-linkoffline", url, path])
        link_files.extend(files)
    for opt in ctx.attr.javadoc_opts:
        args.add(ctx.expand_location(opt, ctx.attr.data))

    java = ctx.actions.args()
    java.add_all(ctx.attr.jvm_flags)
    java.add(ctx.file._launcher)

    ctx.actions.run(
        executable = runtime.java_executable_exec_path,
        arguments = [java, args],
        inputs = depset(
            srcjars + link_files + ctx.files.data + ctx.files.theme + [ctx.file._launcher],
            transitive = [classpath, doclet, runtime.files, elide.compile_tool_files],
        ),
        outputs = [site, archive],
        mnemonic = "ElideApiDocs",
        progress_message = "Generating API reference %{label}",
        # The doclet finds its JavaScript runtime here; other doclets ignore it.
        env = dict(_ENV, APIDOCS_JS_RUNTIME = elide.binary.path),
        toolchain = TOOLCHAIN_TYPE,
    )
    return [
        DefaultInfo(files = depset([site, archive])),
        OutputGroupInfo(apidocs_archive = depset([archive]), apidocs_site = depset([site])),
    ]

elide_apidocs = rule(
    implementation = _apidocs_impl,
    doc = """Generates an API reference site with a custom doclet.

Javadoc runs once, in unnamed-module `-sourcepath` mode, over the unpacked source jars of
`deps` (module descriptors are dropped), the way `mx javadoc --unified` documents several
projects as one reference. The compile classpath is the transitive compile classpath of `deps`,
so public API that refers to annotation-processor-generated classes resolves.

javadoc comes from `java_runtime`: by default the execution-platform runtime that
`--tool_java_runtime_version` selects. elide-dev/doclet needs JDK 25. Documenting GraalVM
sources needs a JDK without GraalVM modules, such as LabsJDK: a GraalVM JDK already contains
`org.graalvm.*`, and javadoc fails with "package exists in another module".

The doclet renders through the Elide binary of the registered Elide toolchain, passed as the
`APIDOCS_JS_RUNTIME` environment variable. Outputs are the site directory (`<name>_site`,
output group `apidocs_site`) and a reproducible `<name>.tar.gz` (output group
`apidocs_archive`).

```starlark
elide_apidocs(
    name = "api_reference",
    deps = [":api"],
    doclet = "@elide_doclet//:doclet",
    packages = ["com.example.api"],
    title = "Example API",
    version = "1.0.0",
)
```
""",
    attrs = {
        "data": attr.label_list(
            allow_files = True,
            doc = "Files that `javadoc_opts` refer to with `$(location)`.",
        ),
        "deps": attr.label_list(
            mandatory = True,
            providers = [JavaInfo],
            doc = "Targets to document. Their source jars are the sources, and their transitive " +
                  "compile jars the classpath.",
        ),
        "doclet": attr.label(
            mandatory = True,
            allow_files = [".jar"],
            cfg = "exec",
            doc = "The doclet: a jar, or a target providing `JavaInfo` (its runtime classpath " +
                  "becomes `-docletpath`). elide-dev/doclet has no release yet; build it from a " +
                  "pinned commit (see docs/api_reference.md).",
        ),
        "doclet_class": attr.string(
            default = "dev.elide.doclet.ElideDoclet",
            doc = "The doclet's class.",
        ),
        "exclude_packages": attr.string_list(
            doc = "Packages left out, with their subpackages (`-exclude`).",
        ),
        "generated_sources": attr.bool(
            default = True,
            doc = "Also document the annotation-processor source jars of `deps`, as " +
                  "`mx javadoc` does. When false, generated classes are still on the classpath.",
        ),
        "java_runtime": attr.label(
            default = "@bazel_tools//tools/jdk:current_java_runtime",
            cfg = "exec",
            providers = [java_common.JavaRuntimeInfo],
            doc = "The JDK that runs javadoc. The default follows `--tool_java_runtime_version`.",
        ),
        "javadoc_opts": attr.string_list(
            doc = "Additional javadoc and doclet options, after the generated ones. " +
                  "`$(location)` expands labels in `data`.",
        ),
        "jvm_flags": attr.string_list(
            doc = "JVM flags for the javadoc process, such as `-Xmx4g`.",
        ),
        "links": attr.string_list(
            doc = "Javadoc sites to link to (`-link`). javadoc downloads each `element-list`, " +
                  "which needs network access in the action; prefer `offline_links`.",
        ),
        "module_name": attr.string(
            doc = "Library name in `api.json` (`--module-name`); defaults to `title`.",
        ),
        "offline_links": attr.string_keyed_label_dict(
            allow_files = True,
            doc = "Javadoc sites to link to without network access (`-linkoffline`): site URL " +
                  "to a label of its `element-list` file, or of a directory holding it.",
        ),
        "packages": attr.string_list(
            doc = "Packages to document, with their subpackages (`-subpackages`). Empty " +
                  "documents every package in the source jars.",
        ),
        "problems": attr.string(
            doc = "How the doclet reports comments it cannot represent (`--problems`), such as " +
                  "`warning` or `error,inheritdoc=warning`. The doclet's default is `error`.",
        ),
        "source_ref": attr.string(
            doc = "Revision for source links (`--source-ref`).",
        ),
        "theme": attr.label(
            allow_single_file = [".json"],
            doc = "Renderer theme JSON (`--theme`).",
        ),
        "title": attr.string(
            doc = "Reference title (`-doctitle` and `-windowtitle`).",
        ),
        "version": attr.string(
            doc = "Library version in `api.json` (`--module-version`).",
        ),
        "_launcher": attr.label(
            default = "//elide/private/apidocs:ApiDocs.java",
            allow_single_file = True,
        ),
    },
    toolchains = [TOOLCHAIN_TYPE],
)
