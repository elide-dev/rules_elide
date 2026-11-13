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
    asserts.true(env, hasattr(info, "kotlin_stdlib_jars"), "kotlin_stdlib_jars field missing")
    asserts.true(env, info.binary in info.jextract_tool_files.to_list())
    asserts.true(env, any([f.basename == "llvm-resource.txt" for f in info.jextract_tool_files.to_list()]))
    asserts.false(env, any([f.basename == "llvm-resource.txt" for f in info.compile_tool_files.to_list()]))
    cc_files = info.cc_tool_files.to_list()
    asserts.equals(env, "fake-linux-gnu-clang", info.cc_compiler.basename)
    asserts.true(env, info.cc_compiler in cc_files)
    asserts.true(env, any([f.basename == "sysroot-resource.txt" for f in cc_files]))
    asserts.false(env, info.binary in cc_files, "C actions must not depend on the elide launcher")
    asserts.false(env, any([f.basename == "sysroot-resource.txt" for f in info.compile_tool_files.to_list()]))
    python_files = info.python_tool_files.to_list()
    asserts.true(env, info.binary in python_files)
    asserts.true(env, any([f.basename == "python-resource.txt" for f in python_files]))
    asserts.false(env, any([f.basename == "python-resource.txt" for f in info.compile_tool_files.to_list()]))
    return analysistest.end(env)

_provider_shape_test = analysistest.make(_provider_shape_test_impl)

def _no_cc_test_impl(ctx):
    env = analysistest.begin(ctx)
    info = analysistest.target_under_test(env)[platform_common.ToolchainInfo].elide_info
    asserts.equals(env, None, info.cc_compiler)
    asserts.equals(env, [], info.cc_tool_files.to_list())
    return analysistest.end(env)

_no_cc_test = analysistest.make(_no_cc_test_impl)

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
    write_file(
        name = "_python_resource",
        out = "python-resource.txt",
        content = ["Python runtime fixture"],
        testonly = True,
        tags = ["manual"],
    )
    write_file(
        name = "_llvm_resource",
        out = "llvm-resource.txt",
        content = ["LLVM fixture"],
        testonly = True,
        tags = ["manual"],
    )
    write_file(
        name = "_cc_compiler",
        out = "fake-linux-gnu-clang",
        content = ["#!/bin/sh", ""],
        is_executable = True,
        testonly = True,
        tags = ["manual"],
    )
    write_file(
        name = "_sysroot_resource",
        out = "sysroot-resource.txt",
        content = ["sysroot fixture"],
        testonly = True,
        tags = ["manual"],
    )
    elide_toolchain(
        name = "_fixture_toolchain_no_cc",
        binary = ":_stub_elide",
        version = "1.2.3",
        testonly = True,
        tags = ["manual"],
    )
    _no_cc_test(
        name = "no_cc_test",
        target_under_test = ":_fixture_toolchain_no_cc",
    )
    elide_toolchain(
        name = "_fixture_toolchain",
        cc_compiler = [":_cc_compiler"],
        cc_tool_files = [":_sysroot_resource"],
        jextract_tool_files = [":_llvm_resource"],
        binary = ":_stub_elide",
        version = "1.2.3",
        python_tool_files = [":_python_resource"],
        testonly = True,
        tags = ["manual"],
    )
    _provider_shape_test(
        name = "provider_shape_test",
        target_under_test = ":_fixture_toolchain",
    )
    native.test_suite(
        name = name,
        tests = [":no_cc_test", ":provider_shape_test"],
    )
