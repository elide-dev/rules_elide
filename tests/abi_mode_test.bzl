"""Per-target ABI choices must override build settings without bypassing fallbacks."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("//elide:defs.bzl", "elide_java_library", "elide_kotlin_library")

def _mode_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    compiler = "ElideJavac" if ctx.attr.language == "java" else "ElideKotlinc"
    full = [a for a in actions if a.mnemonic == compiler]
    headers = [a for a in actions if a.mnemonic == compiler + "Abi"]
    asserts.equals(env, 1, len(full))
    asserts.equals(env, ctx.attr.expected == "separate", bool(headers))
    asserts.equals(env, ctx.attr.expected == "combined", "--emit-abi" in full[0].argv)
    info = analysistest.target_under_test(env)[JavaInfo]
    asserts.equals(env, ctx.attr.expected != "off", any([f.basename.endswith("_abi.jar") for f in info.compile_jars.to_list()]))
    asserts.false(env, any([f.basename.endswith("_abi.jar") for f in info.runtime_output_jars]))
    return analysistest.end(env)

_ATTRS = {"expected": attr.string(), "language": attr.string()}
_default_test = analysistest.make(
    _mode_test_impl,
    attrs = _ATTRS,
    config_settings = {
        "@@//config/javac:abi_compile_avoidance": False,  # buildifier: disable=canonical-repository
        "@@//config/javac:abi_from_compile": False,  # buildifier: disable=canonical-repository
        "@@//config/kotlinc:abi_compile_avoidance": False,  # buildifier: disable=canonical-repository
        "@@//config/kotlinc:abi_from_compile": False,  # buildifier: disable=canonical-repository
    },
)
_enabled_test = analysistest.make(
    _mode_test_impl,
    attrs = _ATTRS,
    config_settings = {
        "@@//config/javac:abi_compile_avoidance": True,  # buildifier: disable=canonical-repository
        "@@//config/javac:abi_from_compile": True,  # buildifier: disable=canonical-repository
        "@@//config/kotlinc:abi_compile_avoidance": True,  # buildifier: disable=canonical-repository
        "@@//config/kotlinc:abi_from_compile": True,  # buildifier: disable=canonical-repository
    },
)

def abi_mode_test_suite(name):
    """Declare both-language override and fallback tests.

    Args:
        name: Suite name.
    """
    tests = []
    for language, rule, extension, text in [
        ("java", elide_java_library, "java", "class Mode {}"),
        ("kotlin", elide_kotlin_library, "kt", "class Mode"),
    ]:
        src = "_mode_src_" + language
        write_file(name = src, out = "abi_mode/Mode." + extension, content = [text], tags = ["manual"])
        for mode in ["inherit", "off", "separate", "combined"]:
            target = "_mode_" + language + "_" + mode
            rule(name = target, srcs = [":" + src], abi_mode = mode, testonly = True, tags = ["manual"])
            for enabled, test in [(False, _default_test), (True, _enabled_test)]:
                test_name = target[1:] + ("_enabled_test" if enabled else "_default_test")
                expected = ("combined" if enabled else "off") if mode == "inherit" else mode
                test(name = test_name, target_under_test = ":" + target, language = language, expected = expected)
                tests.append(":" + test_name)
        target = "_mode_fallback_" + language
        attrs = {"javac_opts": ["-proc:only"]} if language == "java" else {"resources": [":" + src]}
        rule(name = target, srcs = [":" + src], abi_mode = "combined", testonly = True, tags = ["manual"], **attrs)
        test_name = "mode_fallback_" + language + "_test"
        _default_test(name = test_name, target_under_test = ":" + target, language = language, expected = "off" if language == "java" else "separate")
        tests.append(":" + test_name)
    native.test_suite(name = name, tests = tests)
