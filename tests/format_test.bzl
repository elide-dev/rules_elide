# SPDX-License-Identifier: Apache-2.0

"""Analysis tests for elide_format."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//elide/rules:format.bzl", "elide_format")

def _executable_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[DefaultInfo]
    asserts.true(env, info.files_to_run.executable != None, "elide_format must be executable")
    return analysistest.end(env)

_executable_test = analysistest.make(_executable_test_impl)

def format_test_suite(name):
    """Wires fixtures and analysis tests for elide_format.

    Args:
        name: aggregated test_suite target name.
    """
    write_file(
        name = "_fmt_java_src",
        out = "FmtHello.java",
        content = [
            "public class FmtHello {}",
            "",
        ],
        testonly = True,
        tags = ["manual"],
    )
    write_file(
        name = "_fmt_kt_src",
        out = "FmtHello.kt",
        content = [
            "fun fmtHello() {}",
            "",
        ],
        testonly = True,
        tags = ["manual"],
    )
    elide_format(
        name = "_fmt_java_fixture",
        srcs = [":_fmt_java_src"],
        testonly = True,
        tags = ["manual"],
    )
    elide_format(
        name = "_fmt_kt_fixture",
        srcs = [":_fmt_kt_src"],
        testonly = True,
        tags = ["manual"],
    )
    _executable_test(
        name = "fmt_java_executable_test",
        target_under_test = ":_fmt_java_fixture",
    )
    _executable_test(
        name = "fmt_kt_executable_test",
        target_under_test = ":_fmt_kt_fixture",
    )
    native.test_suite(
        name = name,
        tests = [
            ":fmt_java_executable_test",
            ":fmt_kt_executable_test",
        ],
    )
