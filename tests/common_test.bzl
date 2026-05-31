# SPDX-License-Identifier: Apache-2.0

"""Analysis tests for elide/private/common.bzl helpers."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//elide:providers.bzl", "ElideInfo")

# buildifier: disable=bzl-visibility
load("//elide/private:common.bzl", "collect_exported_plugins")

# Test-only fixture: emits ElideInfo with a configurable set of compiler plugins.
def _fake_elide_target_impl(ctx):
    return [ElideInfo(
        exported_compiler_plugins = depset(direct = ctx.attr.plugins),
        manifest = None,
    )]

_fake_elide_target = rule(
    implementation = _fake_elide_target_impl,
    attrs = {
        "plugins": attr.string_list(),
    },
)

# Probe rule: receives a list of deps, calls collect_exported_plugins, and
# exposes the resulting depset size and contents via a struct provider.
_ProbeInfo = provider(
    doc = "Test-only probe of collect_exported_plugins.",
    fields = ["plugin_count", "plugins"],
)

def _probe_impl(ctx):
    merged = collect_exported_plugins(ctx.attr.deps)
    items = sorted(merged.to_list())
    return [_ProbeInfo(plugin_count = len(items), plugins = items)]

_probe = rule(
    implementation = _probe_impl,
    attrs = {
        "deps": attr.label_list(providers = [[ElideInfo]]),
    },
)

def _empty_test_impl(ctx):
    env = analysistest.begin(ctx)
    result = analysistest.target_under_test(env)[_ProbeInfo]
    asserts.equals(env, 0, result.plugin_count)
    return analysistest.end(env)

_empty_test = analysistest.make(_empty_test_impl)

def _merges_two_inputs_test_impl(ctx):
    env = analysistest.begin(ctx)
    result = analysistest.target_under_test(env)[_ProbeInfo]
    asserts.equals(env, 3, result.plugin_count)
    asserts.equals(env, ["plug-a", "plug-b", "plug-c"], result.plugins)
    return analysistest.end(env)

_merges_two_inputs_test = analysistest.make(_merges_two_inputs_test_impl)

def common_test_suite(name):
    """Wires fixtures and analysis tests for common.bzl.

    Args:
        name: test_suite target aggregating all common-helper tests.
    """
    _probe(
        name = "_probe_empty",
        deps = [],
        testonly = True,
        tags = ["manual"],
    )
    _empty_test(
        name = "empty_test",
        target_under_test = ":_probe_empty",
    )

    _fake_elide_target(
        name = "_lib_ab",
        plugins = ["plug-a", "plug-b"],
        testonly = True,
        tags = ["manual"],
    )
    _fake_elide_target(
        name = "_lib_bc",
        plugins = ["plug-b", "plug-c"],
        testonly = True,
        tags = ["manual"],
    )
    _probe(
        name = "_probe_merged",
        deps = [":_lib_ab", ":_lib_bc"],
        testonly = True,
        tags = ["manual"],
    )
    _merges_two_inputs_test(
        name = "merges_two_inputs_test",
        target_under_test = ":_probe_merged",
    )

    native.test_suite(
        name = name,
        tests = [
            ":empty_test",
            ":merges_two_inputs_test",
        ],
    )
