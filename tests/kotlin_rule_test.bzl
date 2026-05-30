"""Analysis tests for elide_kotlin_library and elide_kotlin_binary."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("//elide:providers.bzl", "ElideInfo")
load("//elide/rules:kotlin.bzl", "elide_kotlin_binary", "elide_kotlin_library", "elide_kotlin_test")

def _library_providers_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.true(env, JavaInfo in target, "elide_kotlin_library must emit JavaInfo")
    asserts.true(env, ElideInfo in target, "elide_kotlin_library must emit ElideInfo")
    files = target[DefaultInfo].files.to_list()
    asserts.equals(env, 1, len(files), "expected exactly one output jar")
    asserts.true(env, files[0].path.endswith(".jar"), "output must be a .jar")
    return analysistest.end(env)

_library_providers_test = analysistest.make(_library_providers_test_impl)

def _library_action_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    compile_actions = [a for a in actions if a.mnemonic == "ElideKotlinCompile"]
    asserts.equals(env, 1, len(compile_actions), "expected one ElideKotlinCompile action")
    return analysistest.end(env)

_library_action_test = analysistest.make(_library_action_test_impl)

def _binary_executable_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.true(env, JavaInfo in target, "elide_kotlin_binary must emit JavaInfo")
    asserts.true(env, ElideInfo in target, "elide_kotlin_binary must emit ElideInfo")
    info = target[DefaultInfo]
    asserts.true(env, info.files_to_run.executable != None, "binary must be executable")
    return analysistest.end(env)

_binary_executable_test = analysistest.make(_binary_executable_test_impl)

def _test_rule_executable_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.true(env, JavaInfo in target, "elide_kotlin_test must emit JavaInfo")
    asserts.true(env, ElideInfo in target, "elide_kotlin_test must emit ElideInfo")
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
        name = "_kt_lib_fixture",
        srcs = [":_kt_hello_src"],
        module_name = "hello",
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
            ":kt_binary_executable_test",
            ":kt_test_rule_executable_test",
        ],
    )
