# SPDX-License-Identifier: Apache-2.0

"""Analysis tests for elide_kotlin_library, _binary, _test."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("//elide:providers.bzl", "ElideInfo")
load("//elide/rules:kotlin.bzl", "elide_kotlin_binary", "elide_kotlin_library", "elide_kotlin_test")

def _library_providers_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.true(env, JavaInfo in target, "must emit JavaInfo")
    asserts.true(env, ElideInfo in target, "must emit ElideInfo")
    java_info = target[JavaInfo]
    asserts.true(env, len(java_info.source_jars) > 0, "JavaInfo.source_jars must be non-empty")
    asserts.true(
        env,
        len(java_info.compile_jars.to_list()) > 0,
        "compile_jars (ijar) must be non-empty",
    )
    files = target[DefaultInfo].files.to_list()
    asserts.equals(env, 1, len(files), "expected exactly one output jar")
    asserts.true(env, files[0].path.endswith(".jar"), "output must be a .jar")
    return analysistest.end(env)

_library_providers_test = analysistest.make(_library_providers_test_impl)

def _library_action_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    kotlincs = [a for a in actions if a.mnemonic == "ElideKotlinc"]
    asserts.equals(env, 1, len(kotlincs), "expected one ElideKotlinc action")
    argv = kotlincs[0].argv
    asserts.true(env, "kotlinc" in argv, "expected `kotlinc` subcommand in argv")
    asserts.true(env, "--" in argv, "expected `--` separator before native kotlinc flags")
    asserts.true(env, "-d" in argv, "expected `-d` output flag passed to kotlinc")
    asserts.true(env, "-classpath" in argv, "expected `-classpath` flag passed to kotlinc")
    asserts.true(env, "-module-name" in argv, "expected `-module-name` flag (set on fixture)")
    return analysistest.end(env)

_library_action_test = analysistest.make(_library_action_test_impl)

def _associates_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    kotlincs = [a for a in actions if a.mnemonic == "ElideKotlinc"]
    asserts.equals(env, 1, len(kotlincs), "expected one ElideKotlinc action")
    argv = kotlincs[0].argv
    has_friend = [a for a in argv if a.startswith("-Xfriend-paths=")]
    asserts.equals(
        env,
        1,
        len(has_friend),
        "expected one `-Xfriend-paths=<jar>` arg when `associates` is set",
    )
    return analysistest.end(env)

_associates_test = analysistest.make(_associates_test_impl)

def _binary_executable_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.true(env, JavaInfo in target, "must emit JavaInfo")
    asserts.true(env, ElideInfo in target, "must emit ElideInfo")
    info = target[DefaultInfo]
    asserts.true(env, info.files_to_run.executable != None, "binary must be executable")
    return analysistest.end(env)

_binary_executable_test = analysistest.make(_binary_executable_test_impl)

def _test_rule_executable_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.true(env, JavaInfo in target, "must emit JavaInfo")
    asserts.true(env, ElideInfo in target, "must emit ElideInfo")
    info = target[DefaultInfo]
    asserts.true(env, info.files_to_run.executable != None, "test must be executable")
    return analysistest.end(env)

_test_rule_executable_test = analysistest.make(_test_rule_executable_test_impl)

def kotlin_rule_test_suite(name):
    """Wires fixtures and analysis tests for the Kotlin compile rules.

    Args:
        name: aggregated test_suite target name.
    """
    write_file(
        name = "_kt_hello_src",
        out = "Hello.kt",
        content = [
            "fun main(args: Array<String>) {}",
            "",
        ],
        testonly = True,
        tags = ["manual"],
    )
    elide_kotlin_library(
        name = "_kt_dep_fixture",
        srcs = [":_kt_hello_src"],
        module_name = "dep",
        testonly = True,
        tags = ["manual"],
    )
    elide_kotlin_library(
        name = "_kt_lib_fixture",
        srcs = [":_kt_hello_src"],
        deps = [":_kt_dep_fixture"],
        module_name = "hello",
        testonly = True,
        tags = ["manual"],
    )
    elide_kotlin_library(
        name = "_kt_associate_fixture",
        srcs = [":_kt_hello_src"],
        module_name = "associate",
        associates = [":_kt_lib_fixture"],
        testonly = True,
        tags = ["manual"],
    )
    elide_kotlin_binary(
        name = "_kt_bin_fixture",
        srcs = [":_kt_hello_src"],
        main_class = "HelloKt",
        testonly = True,
        tags = ["manual"],
    )
    elide_kotlin_test(
        name = "_kt_test_fixture",
        srcs = [":_kt_hello_src"],
        test_class = "HelloKt",
        tags = ["manual"],
    )
    _library_providers_test(
        name = "kt_library_providers_test",
        target_under_test = ":_kt_lib_fixture",
    )
    _library_action_test(
        name = "kt_library_action_test",
        target_under_test = ":_kt_lib_fixture",
    )
    _associates_test(
        name = "kt_associates_test",
        target_under_test = ":_kt_associate_fixture",
    )
    _binary_executable_test(
        name = "kt_binary_executable_test",
        target_under_test = ":_kt_bin_fixture",
    )
    _test_rule_executable_test(
        name = "kt_test_rule_executable_test",
        target_under_test = ":_kt_test_fixture",
    )
    native.test_suite(
        name = name,
        tests = [
            ":kt_library_providers_test",
            ":kt_library_action_test",
            ":kt_associates_test",
            ":kt_binary_executable_test",
            ":kt_test_rule_executable_test",
        ],
    )
