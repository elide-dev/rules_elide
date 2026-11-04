# SPDX-License-Identifier: Apache-2.0
"""Runtime provider and declared-input coverage without downloading Python."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_python//python:py_runtime_info.bzl", "PyRuntimeInfo")
load("//elide/python:toolchain.bzl", "register_elide_python_toolchain")

def _runtime_test_impl(ctx):
    env = analysistest.begin(ctx)
    runtime = analysistest.target_under_test(env)[PyRuntimeInfo]
    asserts.equals(env, "graalpy", runtime.implementation_name)
    asserts.equals(env, 3, runtime.interpreter_version_info.major)
    asserts.equals(env, 13, runtime.interpreter_version_info.minor)
    asserts.equals(env, None, runtime.interpreter_path)
    asserts.true(env, runtime.interpreter.basename.endswith("_launcher.sh"))
    names = [file.basename for file in runtime.files.to_list()]
    for required in ["python", "stdlib.py", "_test_stub_elide.sh", "runfiles.bash"]:
        asserts.true(env, required in names, "runtime omitted " + required)
    return analysistest.end(env)

_runtime_test = analysistest.make(_runtime_test_impl)

def python_toolchain_test_suite(name):
    """Create a small fake distribution and verify its runtime provider.

    Args:
        name: Test suite name.
    """
    write_file(name = "_python_marker", out = "python_fixture/conf/components/python", content = ["test"])
    write_file(name = "_python_stdlib", out = "python_fixture/stdlib.py", content = ["# fixture"])
    native.filegroup(name = "_python_files", srcs = [":_python_marker", ":_python_stdlib"])
    register_elide_python_toolchain(
        name = "_python_adapter",
        elide = ":_test_stub_src",
        runtime_files = ":_python_files",
        target_compatible_with = ["@platforms//os:linux", "@platforms//cpu:x86_64"],
    )
    _runtime_test(name = "python_runtime_provider_test", target_under_test = ":_python_adapter_runtime")
    native.test_suite(name = name, tests = [":python_runtime_provider_test"])
