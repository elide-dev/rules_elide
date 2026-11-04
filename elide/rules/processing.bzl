# SPDX-License-Identifier: Apache-2.0

"""Explicit KAPT and KSP2 source-generation actions (Elide 1.6.2+)."""

load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("//elide/private:compile_common.bzl", "TOOLCHAIN_TYPE", "compile_classpath", "runtime_classpath")

def _processing_impl(ctx):
    elide = ctx.toolchains[TOOLCHAIN_TYPE].elide_info
    kind = ctx.attr._kind
    source_jar = ctx.actions.declare_file(ctx.label.name + ".srcjar")
    class_jar = ctx.actions.declare_file(ctx.label.name + "-classes.jar")
    outputs = [source_jar, class_jar]
    cp = compile_classpath(ctx.attr.deps)
    processor_cp = depset(ctx.files.processor_jars, transitive = [runtime_classpath(ctx.attr.processor_deps, [])])
    if not processor_cp.to_list():
        fail("Provide processor_deps or processor_jars")
    args = ctx.actions.args()
    args.add_all(["--no-env", "--no-properties", "kotlinc"])
    args.add("--" + kind + "-sources", source_jar)
    args.add("--" + kind + "-classes", class_jar)
    stubs = []
    if kind == "kapt":
        stub = ctx.actions.declare_file(ctx.label.name + "-stubs.jar")
        args.add("--kapt-stubs", stub)
        outputs.append(stub)
        stubs.append(stub)
        if ctx.attr.processors:
            args.add_joined("--processors", ctx.attr.processors, join_with = ",")
    elif ctx.attr.processors:
        fail("KSP discovers SymbolProcessorProvider services; processors is only valid for KAPT")
    args.add_joined("--processorpath", processor_cp, join_with = ctx.configuration.host_path_separator)
    for key, value in sorted(ctx.attr.processor_options.items()):
        args.add("--processor-option", key + "=" + value)
    args.add("--")
    args.add_joined("-classpath", cp, join_with = ctx.configuration.host_path_separator)
    args.add_all(ctx.attr.kotlinc_opts)
    args.add_all(ctx.files.srcs)
    ctx.actions.run(
        executable = elide.binary,
        arguments = [args],
        inputs = depset(ctx.files.srcs + ctx.files.data, transitive = [cp, processor_cp, elide.compile_tool_files]),
        outputs = outputs,
        mnemonic = "ElideKapt" if kind == "kapt" else "ElideKsp",
        env = {"ELIDE_BAZEL": "1"},
    )
    return [
        DefaultInfo(files = depset([source_jar])),
        OutputGroupInfo(generated_sources = depset([source_jar]), generated_classes = depset([class_jar]), stubs = depset(stubs)),
    ]

_ATTRS = {
    "data": attr.label_list(allow_files = True, doc = "Additional files read by processors."),
    "deps": attr.label_list(providers = [JavaInfo], doc = "Source compile classpath."),
    "kotlinc_opts": attr.string_list(),
    "processor_deps": attr.label_list(providers = [JavaInfo], cfg = "exec", doc = "Processor runtime dependencies."),
    "processor_jars": attr.label_list(allow_files = [".jar"], cfg = "exec", doc = "Additional processor jars."),
    "processor_options": attr.string_dict(doc = "Processor options passed as key=value."),
    "processors": attr.string_list(doc = "KAPT processor class names; empty means service discovery."),
    "srcs": attr.label_list(allow_files = [".kt", ".java"], mandatory = True),
}

elide_kapt = rule(
    implementation = _processing_impl,
    attrs = dict(_ATTRS, _kind = attr.string(default = "kapt")),
    toolchains = [TOOLCHAIN_TYPE],
)

elide_ksp = rule(
    implementation = _processing_impl,
    attrs = dict(_ATTRS, _kind = attr.string(default = "ksp")),
    toolchains = [TOOLCHAIN_TYPE],
)
