# SPDX-License-Identifier: Apache-2.0
"""Analysis coverage for the public JVM tools and processor rules."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//elide:defs.bzl", "elide_jar", "elide_javadoc", "elide_javap", "elide_jdeps", "elide_jextract", "elide_kapt", "elide_ksp")

def _tools_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    matches = [a for a in actions if a.mnemonic == ctx.attr.mnemonic]
    asserts.equals(env, 1, len(matches))
    if matches:
        action = matches[0]
        for flag in ctx.attr.flags:
            asserts.true(env, flag in action.argv, "missing " + flag)
        for name in ctx.attr.input_names:
            asserts.true(env, any([f.basename == name for f in action.inputs.to_list()]), "undeclared input " + name)
    for suffix in ctx.attr.output_suffixes:
        asserts.true(env, any([f.path.endswith(suffix) for a in actions for f in a.outputs.to_list()]), "missing output " + suffix)
    return analysistest.end(env)

_tools_test = analysistest.make(
    _tools_test_impl,
    attrs = {
        "mnemonic": attr.string(),
        "flags": attr.string_list(),
        "input_names": attr.string_list(),
        "output_suffixes": attr.string_list(),
    },
)

def jvm_tools_test_suite(name):
    """Defines analysis-only fixtures and a suite.

    Args:
        name: Test suite name.
    """
    for file, content in [("Doc.java", "public class Doc {}"), ("api.h", "int add(int a, int b);"), ("types.h", "typedef int number;"), ("processor.jar", "analysis-only fixture")]:
        write_file(name = "_tool_" + file, out = "tool_fixture/" + file, content = [content], tags = ["manual"])
    common = {"tags": ["manual"], "testonly": True}
    elide_javadoc(name = "_doc", srcs = [":_tool_Doc.java"], theme = "elide", **common)
    elide_jar(name = "_archive", srcs = [":_tool_Doc.java"], strip_prefix = "tests/tool_fixture", **common)
    elide_jdeps(name = "_jdeps", srcs = [":_dep_lib_fixture"], **common)
    elide_javap(name = "_javap", deps = [":_dep_lib_fixture"], classes = ["Hello"], **common)
    elide_jextract(name = "_extract", srcs = [":_tool_api.h"], hdrs = [":_tool_types.h"], package = "bindings", **common)
    elide_kapt(name = "_kapt", srcs = [":_tool_Doc.java"], processor_jars = [":_tool_processor.jar"], processors = ["example.P"], processor_options = {"name": "Generated"}, **common)
    elide_ksp(name = "_ksp", srcs = [":_tool_Doc.java"], processor_jars = [":_tool_processor.jar"], **common)
    cases = [
        ("doc", "ElideJavadoc", ["--theme", "elide", "-notimestamp"], ["Doc.java"], ["-javadoc.jar", "_html"]),
        ("archive", "ElideJar", ["--date=1980-01-01T00:00:02Z", "Doc.java"], ["Doc.java"], [".jar"]),
        ("jdeps", "ElideJdeps", ["jdeps"], [], [".txt"]),
        ("javap", "ElideJavap", ["javap", "Hello"], [], [".txt"]),
        ("extract", "ElideJextract", ["--target-package", "bindings", "-I"], ["api.h", "types.h"], [".srcjar", "_sources"]),
        ("kapt", "ElideKapt", ["--kapt-sources", "--kapt-stubs", "--processors", "example.P", "--processor-option", "name=Generated"], ["processor.jar"], [".srcjar", "-classes.jar", "-stubs.jar"]),
        ("ksp", "ElideKsp", ["--ksp-sources", "--ksp-classes", "--processorpath"], ["processor.jar"], [".srcjar", "-classes.jar"]),
    ]
    for case, mnemonic, flags, inputs, outputs in cases:
        _tools_test(name = case + "_tool_test", target_under_test = ":_" + case, mnemonic = mnemonic, flags = flags, input_names = inputs, output_suffixes = outputs)
    native.test_suite(name = name, tests = [":" + case[0] + "_tool_test" for case in cases])
