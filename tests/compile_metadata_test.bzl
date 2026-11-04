# SPDX-License-Identifier: Apache-2.0
"""Native dependency reports and conservative pruning wiring."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

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
    native.test_suite(name = name, tests = [":java_metadata_test", ":processor_metadata_test", ":kotlin_metadata_test", ":mixed_metadata_test", ":plugin_metadata_test"])
