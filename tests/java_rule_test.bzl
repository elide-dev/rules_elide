"""Analysis tests for elide_java_library and elide_java_binary."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("//elide:providers.bzl", "ElideInfo")
load("//elide/rules:java.bzl", "elide_java_binary", "elide_java_library")

def _library_providers_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.true(env, JavaInfo in target, "elide_java_library must emit JavaInfo")
    asserts.true(env, ElideInfo in target, "elide_java_library must emit ElideInfo")
    files = target[DefaultInfo].files.to_list()
    asserts.equals(env, 1, len(files), "expected exactly one output jar")
    asserts.true(env, files[0].path.endswith(".jar"), "output must be a .jar")
    return analysistest.end(env)

_library_providers_test = analysistest.make(_library_providers_test_impl)

def _library_action_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    compile_actions = [a for a in actions if a.mnemonic == "ElideJavaCompile"]
    asserts.equals(env, 1, len(compile_actions), "expected one ElideJavaCompile action")
    return analysistest.end(env)

_library_action_test = analysistest.make(_library_action_test_impl)

def _binary_executable_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.true(env, JavaInfo in target, "elide_java_binary must emit JavaInfo")
    asserts.true(env, ElideInfo in target, "elide_java_binary must emit ElideInfo")
    info = target[DefaultInfo]
    asserts.true(env, info.files_to_run.executable != None, "binary must be executable")
    return analysistest.end(env)

_binary_executable_test = analysistest.make(_binary_executable_test_impl)

def java_rule_test_suite(name):
    """Wires fixtures and analysis tests for the Java compile rules.

    Args:
        name: aggregated test_suite target name.
    """
    write_file(
        name = "_hello_src",
        out = "Hello.java",
        content = [
            "public class Hello { public static void main(String[] a) {} }",
            "",
        ],
        testonly = True,
        tags = ["manual"],
    )
    elide_java_library(
        name = "_lib_fixture",
        srcs = [":_hello_src"],
        testonly = True,
        tags = ["manual"],
    )
    elide_java_binary(
        name = "_bin_fixture",
        srcs = [":_hello_src"],
        main_class = "Hello",
        testonly = True,
        tags = ["manual"],
    )
    _library_providers_test(
        name = "library_providers_test",
        target_under_test = ":_lib_fixture",
    )
    _library_action_test(
        name = "library_action_test",
        target_under_test = ":_lib_fixture",
    )
    _binary_executable_test(
        name = "binary_executable_test",
        target_under_test = ":_bin_fixture",
    )
    native.test_suite(
        name = name,
        tests = [
            ":library_providers_test",
            ":library_action_test",
            ":binary_executable_test",
        ],
    )
