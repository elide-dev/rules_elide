# SPDX-License-Identifier: Apache-2.0

"""Analysis tests for elide_native_image."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//elide/rules:java.bzl", "elide_java_library")
load("//elide/rules:native_image.bzl", "elide_native_image")

def _native_image_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[DefaultInfo]
    asserts.true(env, info.files_to_run.executable != None, "native image must be executable")
    actions = analysistest.target_actions(env)
    native_actions = [a for a in actions if a.mnemonic == "ElideNativeImage"]
    asserts.equals(env, 1, len(native_actions), "expected one ElideNativeImage action")
    argv = native_actions[0].argv
    asserts.true(env, "native-image" in argv, "expected `native-image` subcommand in argv")
    asserts.true(env, "--" in argv, "expected `--` separator before native-image flags")
    asserts.true(env, "--no-fallback" in argv, "expected `--no-fallback` (hermetic build)")
    asserts.true(env, "-classpath" in argv, "expected `-classpath` flag")
    asserts.true(env, "-o" in argv, "expected `-o` output flag")
    has_worker_tag = "supports-workers" in (native_actions[0].mnemonic + "")
    asserts.false(env, has_worker_tag, "native-image is single-shot AOT — no worker tag")
    return analysistest.end(env)

_native_image_test = analysistest.make(_native_image_test_impl)

def native_image_test_suite(name):
    """Wires fixtures and analysis tests for elide_native_image.

    Args:
        name: aggregated test_suite target name.
    """
    write_file(
        name = "_ni_src",
        out = "NIHello.java",
        content = [
            "public class NIHello { public static void main(String[] a) {} }",
            "",
        ],
        testonly = True,
        tags = ["manual"],
    )
    elide_java_library(
        name = "_ni_lib",
        srcs = [":_ni_src"],
        testonly = True,
        tags = ["manual"],
    )
    elide_native_image(
        name = "_ni_fixture",
        main_class = "NIHello",
        deps = [":_ni_lib"],
        testonly = True,
        tags = ["manual"],
    )
    _native_image_test(
        name = "native_image_test",
        target_under_test = ":_ni_fixture",
    )
    native.test_suite(
        name = name,
        tests = [":native_image_test"],
    )
