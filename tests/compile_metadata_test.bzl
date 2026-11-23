# SPDX-License-Identifier: Apache-2.0
"""Native dependency reports and conservative pruning wiring."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("//elide:defs.bzl", "elide_java_library", "elide_kotlin_library")

def _metadata_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    actions = [a for a in analysistest.target_actions(env) if a.mnemonic in ["ElideJavac", "ElideKotlinc", "ElideKotlinJavac", "ElideJavacAbi", "ElideKotlincAbi"]]
    asserts.true(env, bool(actions))
    for action in actions:
        asserts.true(env, action.argv.index("--jdeps") < action.argv.index("--"))
        asserts.true(env, any([arg.startswith("--target-label=") for arg in action.argv]))
        asserts.equals(env, ctx.attr.pruned, "--unused-inputs" in action.argv)
        asserts.true(env, any([f.extension == "jdeps" for f in action.outputs.to_list()]))
    asserts.equals(env, len(actions), len(target[OutputGroupInfo].jdeps.to_list()))
    asserts.equals(env, len(actions) if ctx.attr.pruned else 0, len(target[OutputGroupInfo].unused_inputs.to_list()))
    return analysistest.end(env)

_metadata_test = analysistest.make(
    _metadata_test_impl,
    attrs = {"pruned": attr.bool(default = True)},
    config_settings = {
        "@@//elide:emit_jdeps": True,  # buildifier: disable=canonical-repository
        "@@//elide:prune_unused_inputs": True,  # buildifier: disable=canonical-repository
    },
)

def _unified_metadata_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    actions = [a for a in analysistest.target_actions(env) if a.mnemonic.startswith("Elide")]
    asserts.equals(env, ["ElideJvmCompile"], [a.mnemonic for a in actions])
    action = actions[0]
    asserts.true(env, "--unified" in action.argv)
    asserts.true(env, "--request-version=1" in action.argv)
    asserts.false(env, "--unused-inputs" in action.argv)
    asserts.equals(env, ctx.attr.facts, "--rote-facts" in action.argv)
    asserts.equals(env, 1 if ctx.attr.facts else 0, len(target[OutputGroupInfo].rote_facts.to_list()))
    asserts.equals(env, 1, len(target[OutputGroupInfo].javadoc_data.to_list()))
    asserts.equals(env, 1, len(target[OutputGroupInfo].jdeps.to_list()))
    asserts.true(env, target[JavaInfo].compile_jars.to_list()[0].basename.endswith("_abi.jar"))
    asserts.false(env, target[JavaInfo].runtime_output_jars[0].basename.endswith("_abi.jar"))
    return analysistest.end(env)

_unified_metadata_test = analysistest.make(
    _unified_metadata_impl,
    attrs = {"facts": attr.bool()},
    config_settings = {
        "@@//elide:emit_jdeps": True,  # buildifier: disable=canonical-repository
        "@@//elide:prune_unused_inputs": True,  # buildifier: disable=canonical-repository
        "@@//elide:use_workers": False,  # buildifier: disable=canonical-repository
    },
)

def compile_metadata_test_suite(name):
    """Defines native compiler metadata tests.

    Args:
        name: Test suite name.
    """
    _metadata_test(name = "java_metadata_test", target_under_test = ":_lib_fixture")
    _metadata_test(name = "processor_metadata_test", target_under_test = ":_processor_fixture", pruned = False)
    _metadata_test(name = "kotlin_metadata_test", target_under_test = ":_kt_lib_fixture")
    _metadata_test(name = "mixed_metadata_test", target_under_test = ":_kt_mixed_fixture")
    _metadata_test(name = "plugin_metadata_test", target_under_test = ":_kt_plugins_fixture", pruned = False)
    write_file(name = "_unified_java_src", out = "unified/JavaApi.java", content = ["public class JavaApi {}"], tags = ["manual"])
    write_file(name = "_unified_kotlin_src", out = "unified/KotlinApi.kt", content = ["class KotlinApi"], tags = ["manual"])
    elide_java_library(
        name = "_unified_java",
        srcs = [":_unified_java_src"],
        compile_mode = "unified",
        unified_outputs = ["abi", "javadoc"],
        tags = ["manual"],
    )
    elide_kotlin_library(
        name = "_unified_mixed",
        srcs = [":_unified_java_src", ":_unified_kotlin_src"],
        compile_mode = "unified",
        unified_outputs = ["abi", "classes", "javadoc", "rote_facts"],
        tags = ["manual"],
    )
    _unified_metadata_test(name = "unified_java_metadata_test", target_under_test = ":_unified_java")
    _unified_metadata_test(name = "unified_mixed_metadata_test", target_under_test = ":_unified_mixed", facts = True)
    native.test_suite(name = name, tests = [
        ":java_metadata_test",
        ":processor_metadata_test",
        ":kotlin_metadata_test",
        ":mixed_metadata_test",
        ":plugin_metadata_test",
        ":unified_java_metadata_test",
        ":unified_mixed_metadata_test",
    ])
