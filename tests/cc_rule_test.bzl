# SPDX-License-Identifier: Apache-2.0

"""Analysis tests for elide_cc_binary action shape and declared inputs."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//elide:defs.bzl", "elide_cc_binary")

def _actions(env, mnemonic):
    return [a for a in analysistest.target_actions(env) if a.mnemonic == mnemonic]

def _basenames(action):
    return [f.basename for f in action.inputs.to_list()]

def _binary_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    compiles = _actions(env, "ElideCcCompile")
    links = _actions(env, "ElideCcLink")
    asserts.equals(env, 2, len(compiles), "one compile action per .c source")
    asserts.equals(env, 1, len(links))

    for action in compiles:
        argv = action.argv
        asserts.true(env, argv[0].endswith("_test_stub_clang"), "compile must run the toolchain's clang: " + argv[0])
        asserts.true(env, "-no-canonical-prefixes" in argv)
        asserts.true(env, "-c" in argv)
        asserts.true(env, "-DGREETING=42" in argv)
        asserts.true(env, "-O2" in argv)
        asserts.true(env, "-lm" not in argv, "linkopts must not reach compile actions")
        inputs = _basenames(action)
        asserts.true(env, "_test_cc_sysroot.txt" in inputs, "toolchain cc_tool_files must be declared")
        asserts.true(env, "_cc_greet.h" in inputs, "headers must be declared")
        asserts.false(env, "_test_stub_elide_bin" in inputs, "C actions must not ship the elide launcher")
        asserts.equals(env, {}, action.env, "C actions must not inherit host environment")

    link = links[0]
    asserts.true(env, "-no-canonical-prefixes" in link.argv)
    asserts.true(env, "-lm" in link.argv)
    asserts.true(env, "-c" not in link.argv)
    link_inputs = _basenames(link)
    asserts.true(env, "_cc_main.o" in link_inputs)
    asserts.true(env, "_cc_greet.o" in link_inputs)
    asserts.true(env, "_test_cc_sysroot.txt" in link_inputs)
    asserts.equals(env, {}, link.env)

    executable = target[DefaultInfo].files_to_run.executable
    asserts.equals(env, link.outputs.to_list(), [executable])
    return analysistest.end(env)

_binary_test = analysistest.make(_binary_test_impl)

def _missing_compiler_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "has no bundled LLVM C compiler")
    return analysistest.end(env)

_missing_compiler_test = analysistest.make(
    _missing_compiler_test_impl,
    expect_failure = True,
    config_settings = {
        "//command_line_option:extra_toolchains": [str(Label("//tests:_test_elide_no_cc_toolchain"))],
    },
)

def _no_sources_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "at least one .c file")
    return analysistest.end(env)

_no_sources_test = analysistest.make(_no_sources_test_impl, expect_failure = True)

def cc_rule_test_suite(name):
    """Registers elide_cc_binary analysis tests.

    Args:
        name: test_suite target name.
    """
    common = {"tags": ["manual"], "testonly": True}
    write_file(name = "_cc_main_src", out = "_cc_main.c", content = ["int main(void) { return 0; }"], **common)
    write_file(name = "_cc_greet_src", out = "_cc_greet.c", content = ["int greet(void) { return GREETING; }"], **common)
    write_file(name = "_cc_greet_hdr", out = "_cc_greet.h", content = ["int greet(void);"], **common)
    elide_cc_binary(
        name = "_cc_binary",
        srcs = [":_cc_main_src", ":_cc_greet_src"],
        hdrs = [":_cc_greet_hdr"],
        copts = ["-O2"],
        defines = ["GREETING=42"],
        linkopts = ["-lm"],
        **common
    )
    _binary_test(name = "binary_test", target_under_test = ":_cc_binary")
    _missing_compiler_test(name = "missing_compiler_test", target_under_test = ":_cc_binary")
    elide_cc_binary(name = "_cc_header_only", srcs = [":_cc_greet_hdr"], **common)
    _no_sources_test(name = "no_sources_test", target_under_test = ":_cc_header_only")
    native.test_suite(
        name = name,
        tests = [":binary_test", ":missing_compiler_test", ":no_sources_test"],
    )
