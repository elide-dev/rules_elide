# SPDX-License-Identifier: Apache-2.0

"""Analysis tests for the elide_toolchain rule."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:native_binary.bzl", "native_binary")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//elide:toolchain.bzl", "elide_toolchain")

def _provider_shape_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.true(
        env,
        platform_common.ToolchainInfo in target,
        "Expected ToolchainInfo provider on elide_toolchain target",
    )
    info = target[platform_common.ToolchainInfo].elide_info
    asserts.equals(env, "1.2.3", info.version)
    asserts.true(env, info.binary != None, "binary must not be None")
    asserts.true(env, hasattr(info, "tool_files"), "tool_files field missing")
    return analysistest.end(env)

_provider_shape_test = analysistest.make(_provider_shape_test_impl)

def elide_toolchain_test_suite(name):
    """Wires fixtures and registers all elide_toolchain analysis tests.

    Args:
        name: test_suite target name aggregating all toolchain tests.
    """
    write_file(
        name = "_stub_elide_src",
        out = "_stub_elide.sh",
        content = [
            "#!/bin/sh",
            "exit 0",
            "",
        ],
        is_executable = True,
        testonly = True,
        tags = ["manual"],
    )
    native_binary(
        name = "_stub_elide",
        src = ":_stub_elide_src",
        out = "_stub_elide_bin",
        testonly = True,
        tags = ["manual"],
    )
    elide_toolchain(
        name = "_fixture_toolchain",
        binary = ":_stub_elide",
        version = "1.2.3",
        testonly = True,
        tags = ["manual"],
    )
    _provider_shape_test(
        name = "provider_shape_test",
        target_under_test = ":_fixture_toolchain",
    )
    native.test_suite(
        name = name,
        tests = [":provider_shape_test"],
    )
