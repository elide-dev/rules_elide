# SPDX-License-Identifier: Apache-2.0

"""Analysis tests for elide_kotlin_library, _binary, _test."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_java//java:java_library.bzl", "java_library")
load("@rules_java//java:java_plugin.bzl", "java_plugin")
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

    # Both worker and one-shot now share the same arg form: `elide kotlinc --
    # <TOOL_ARGS>`. As of Elide 1.3.1 the worker accepts the leading `--`, so
    # it is always present. Bazel injects `--persistent_worker` when it spawns
    # the worker, so the rule must not pass it.
    asserts.false(
        env,
        "--persistent_worker" in argv,
        "rule must not pass `--persistent_worker`; Bazel injects it for workers",
    )
    asserts.true(env, "--" in argv, "expected the `--` separator before bare TOOL_ARGS")
    asserts.true(env, "-d" in argv, "expected `-d` output flag passed to kotlinc")
    asserts.true(env, "-classpath" in argv, "expected `-classpath` flag passed to kotlinc")
    asserts.true(env, "-module-name" in argv, "expected `-module-name` flag (set on fixture)")
    asserts.equals(
        env,
        "1",
        kotlincs[0].env.get("ELIDE_BAZEL", ""),
        "ElideKotlinc must run with ELIDE_BAZEL=1 (Bazel signal for elide output; WHIPLASH#1131)",
    )
    return analysistest.end(env)

_library_action_test = analysistest.make(_library_action_test_impl)

def _abi_avoidance_test_impl(ctx):
    # With //config/kotlinc:abi_compile_avoidance=True, a kt-only target emits a
    # dedicated `elide kotlinc --abi-only` header action, and its JavaInfo
    # compile_jar is that header jar (not the run_ijar-derived jar) — so a
    # body-only edit yields a byte-identical header and dependents prune.
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    abis = [a for a in actions if a.mnemonic == "ElideKotlincAbi"]
    asserts.equals(env, 1, len(abis), "expected one ElideKotlincAbi (--abi-only) action")
    argv = abis[0].argv
    asserts.true(env, "--abi-only" in argv, "abi action must pass `--abi-only`")
    asserts.true(
        env,
        argv.index("--abi-only") < argv.index("--"),
        "`--abi-only` is an elide option; must precede the `--` separator",
    )
    abi_out = abis[0].outputs.to_list()
    asserts.true(
        env,
        len(abi_out) == 1 and abi_out[0].basename.endswith("_abi.jar"),
        "abi action must output a single `_abi.jar`",
    )

    # compile_jar is wired to the header jar, not an ijar.
    compile_jars = analysistest.target_under_test(env)[JavaInfo].compile_jars.to_list()
    asserts.true(
        env,
        any([j.basename.endswith("_abi.jar") for j in compile_jars]),
        "compile_jar must be the `--abi-only` header jar when avoidance is on",
    )
    return analysistest.end(env)

_abi_avoidance_test = analysistest.make(
    _abi_avoidance_test_impl,
    # See _library_action_no_worker_test re: the @@ canonical root ref.
    config_settings = {"@@//config/kotlinc:abi_compile_avoidance": True},  # buildifier: disable=canonical-repository
)

def _abi_avoidance_mixed_fallback_test_impl(ctx):
    # `elide kotlinc --abi-only` emits Kotlin ABI only, so mixed kt+java targets
    # must NOT take the abi path (a Kotlin-only header would drop the Java ABI
    # and break dependents). They fall back to the run_ijar compile jar.
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    asserts.equals(
        env,
        0,
        len([a for a in actions if a.mnemonic == "ElideKotlincAbi"]),
        "mixed kt+java must not emit an --abi-only action (Kotlin-only ABI)",
    )
    compile_jars = analysistest.target_under_test(env)[JavaInfo].compile_jars.to_list()
    asserts.true(
        env,
        not any([j.basename.endswith("_abi.jar") for j in compile_jars]),
        "mixed target compile_jar must be the run_ijar jar, not an `_abi.jar`",
    )
    return analysistest.end(env)

_abi_avoidance_mixed_fallback_test = analysistest.make(
    _abi_avoidance_mixed_fallback_test_impl,
    config_settings = {"@@//config/kotlinc:abi_compile_avoidance": True},  # buildifier: disable=canonical-repository
)

def _builtin_plugins_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    kotlincs = [a for a in actions if a.mnemonic == "ElideKotlinc"]
    asserts.equals(env, 1, len(kotlincs), "expected one ElideKotlinc action")
    argv = kotlincs[0].argv
    plugins = [a for a in argv if a.startswith("--plugins=")]
    asserts.equals(env, 1, len(plugins), "expected exactly one `--plugins=` arg")
    asserts.equals(
        env,
        "--plugins=serialization,metro",
        plugins[0],
        "builtin_plugins must be comma-joined into a single --plugins= value",
    )

    # `--plugins` is an Elide option, so it must precede the `--` separator that
    # introduces the bare kotlinc TOOL_ARGS.
    asserts.true(
        env,
        argv.index(plugins[0]) < argv.index("--"),
        "`--plugins` must come before the `--` separator",
    )
    return analysistest.end(env)

_builtin_plugins_test = analysistest.make(_builtin_plugins_test_impl)

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

def _resources_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)

    kotlincs = [a for a in actions if a.mnemonic == "ElideKotlinc"]
    asserts.equals(env, 1, len(kotlincs), "expected one ElideKotlinc action")
    kt_outs = [f.basename for f in kotlincs[0].outputs.to_list()]
    asserts.true(
        env,
        "_kt_resources_fixture_kotlin_classes.jar" in kt_outs,
        "kotlinc must emit the intermediate classes jar when resources are present",
    )

    merges = [a for a in actions if a.mnemonic == "ElideResourceJar"]
    asserts.equals(env, 1, len(merges), "expected one ElideResourceJar action")
    argv = merges[0].argv
    asserts.true(env, "--resources" in argv, "expected `--resources` flag")
    stripped = [a for a in argv if a.endswith(":res/data.txt")]
    asserts.equals(
        env,
        1,
        len(stripped),
        "resource must be placed at `res/data.txt` (resource_strip_prefix stripped)",
    )

    files = analysistest.target_under_test(env)[DefaultInfo].files.to_list()
    asserts.equals(env, 1, len(files), "expected exactly one output jar")
    asserts.true(
        env,
        files[0].basename == "_kt_resources_fixture.jar",
        "final output must be the named jar",
    )
    return analysistest.end(env)

_resources_test = analysistest.make(_resources_test_impl)

def _mixed_sources_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)

    kotlincs = [a for a in actions if a.mnemonic == "ElideKotlinc"]
    asserts.equals(env, 1, len(kotlincs), "expected one ElideKotlinc action")
    javacs = [a for a in actions if a.mnemonic == "ElideKotlinJavac"]
    asserts.equals(env, 1, len(javacs), "expected one ElideKotlinJavac action for the .java srcs")

    merges = [a for a in actions if a.mnemonic == "ElideResourceJar"]
    asserts.equals(env, 1, len(merges), "expected one merge action")
    argv = merges[0].argv
    has_kt = [a for a in argv if a.endswith("_kt_mixed_fixture_kotlin_classes.jar")]
    has_java = [a for a in argv if a.endswith("_kt_mixed_fixture_java_classes.jar")]
    asserts.equals(env, 1, len(has_kt), "merge must include the Kotlin classes jar")
    asserts.equals(env, 1, len(has_java), "merge must include the Java classes jar")
    return analysistest.end(env)

_mixed_sources_test = analysistest.make(_mixed_sources_test_impl)

def _resource_only_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)

    asserts.equals(
        env,
        0,
        len([a for a in actions if a.mnemonic in ("ElideKotlinc", "ElideKotlinJavac")]),
        "resource-only target must not invoke kotlinc/javac",
    )

    merges = [a for a in actions if a.mnemonic == "ElideResourceJar"]
    asserts.equals(env, 1, len(merges), "expected one merge action")
    argv = merges[0].argv
    asserts.true(env, "--resources" in argv, "expected `--resources` flag")
    asserts.true(
        env,
        len([a for a in argv if a.endswith(":res/only.txt")]) == 1,
        "resource must be placed at `res/only.txt` (resource_strip_prefix stripped)",
    )
    return analysistest.end(env)

_resource_only_test = analysistest.make(_resource_only_test_impl)

def _annotation_processor_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)

    asserts.equals(
        env,
        0,
        len([a for a in actions if a.mnemonic in ("ElideKotlinJavac", "ElideKotlinJavacJar")]),
        "elide javac must not be used when annotation processors are present",
    )
    javacs = [a for a in actions if a.mnemonic == "Javac"]
    asserts.true(env, len(javacs) >= 1, "expected a regular Javac action for the .java srcs")

    merges = [a for a in actions if a.mnemonic == "ElideResourceJar"]
    asserts.equals(env, 1, len(merges), "expected one merge action")
    argv = merges[0].argv
    asserts.equals(
        env,
        1,
        len([a for a in argv if a.endswith("_kt_ap_fixture_java_classes.jar")]),
        "merge must include the Java classes jar",
    )
    return analysistest.end(env)

_annotation_processor_test = analysistest.make(_annotation_processor_test_impl)

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
        name = "_kt_plugins_fixture",
        srcs = [":_kt_hello_src"],
        module_name = "plugins",
        builtin_plugins = ["serialization", "metro"],
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
    write_file(
        name = "_kt_res_src",
        out = "res/data.txt",
        content = ["payload", ""],
        testonly = True,
        tags = ["manual"],
    )
    elide_kotlin_library(
        name = "_kt_resources_fixture",
        srcs = [":_kt_hello_src"],
        resources = [":_kt_res_src"],
        resource_strip_prefix = "tests",
        module_name = "resources",
        testonly = True,
        tags = ["manual"],
    )
    write_file(
        name = "_kt_java_src",
        out = "Aux.java",
        content = ["public class Aux {}", ""],
        testonly = True,
        tags = ["manual"],
    )
    elide_kotlin_library(
        name = "_kt_mixed_fixture",
        srcs = [":_kt_hello_src", ":_kt_java_src"],
        module_name = "mixed",
        testonly = True,
        tags = ["manual"],
    )
    write_file(
        name = "_kt_res_only_src",
        out = "res/only.txt",
        content = ["only", ""],
        testonly = True,
        tags = ["manual"],
    )
    elide_kotlin_library(
        name = "_kt_resource_only_fixture",
        resources = [":_kt_res_only_src"],
        resource_strip_prefix = "tests",
        testonly = True,
        tags = ["manual"],
    )
    write_file(
        name = "_kt_proc_src",
        out = "FakeProcessor.java",
        content = ["package com.example;", "public class FakeProcessor {}", ""],
        testonly = True,
        tags = ["manual"],
    )
    java_library(
        name = "_kt_proc_impl",
        srcs = [":_kt_proc_src"],
        testonly = True,
        tags = ["manual"],
    )
    java_plugin(
        name = "_kt_fake_processor",
        processor_class = "com.example.FakeProcessor",
        generates_api = True,
        deps = [":_kt_proc_impl"],
        testonly = True,
        tags = ["manual"],
    )
    java_library(
        name = "_kt_ap_exporter",
        exported_plugins = [":_kt_fake_processor"],
        testonly = True,
        tags = ["manual"],
    )
    elide_kotlin_library(
        name = "_kt_ap_fixture",
        srcs = [":_kt_hello_src", ":_kt_java_src"],
        deps = [":_kt_ap_exporter"],
        module_name = "ap",
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
    _builtin_plugins_test(
        name = "kt_builtin_plugins_test",
        target_under_test = ":_kt_plugins_fixture",
    )
    _associates_test(
        name = "kt_associates_test",
        target_under_test = ":_kt_associate_fixture",
    )
    _resources_test(
        name = "kt_resources_test",
        target_under_test = ":_kt_resources_fixture",
    )
    _mixed_sources_test(
        name = "kt_mixed_sources_test",
        target_under_test = ":_kt_mixed_fixture",
    )
    _resource_only_test(
        name = "kt_resource_only_test",
        target_under_test = ":_kt_resource_only_fixture",
    )
    _annotation_processor_test(
        name = "kt_annotation_processor_test",
        target_under_test = ":_kt_ap_fixture",
    )
    _binary_executable_test(
        name = "kt_binary_executable_test",
        target_under_test = ":_kt_bin_fixture",
    )
    _test_rule_executable_test(
        name = "kt_test_rule_executable_test",
        target_under_test = ":_kt_test_fixture",
    )
    _abi_avoidance_test(
        name = "kt_abi_avoidance_test",
        target_under_test = ":_kt_lib_fixture",
    )
    _abi_avoidance_mixed_fallback_test(
        name = "kt_abi_avoidance_mixed_fallback_test",
        target_under_test = ":_kt_mixed_fixture",
    )
    native.test_suite(
        name = name,
        tests = [
            ":kt_library_providers_test",
            ":kt_library_action_test",
            ":kt_builtin_plugins_test",
            ":kt_associates_test",
            ":kt_resources_test",
            ":kt_mixed_sources_test",
            ":kt_resource_only_test",
            ":kt_annotation_processor_test",
            ":kt_binary_executable_test",
            ":kt_test_rule_executable_test",
            ":kt_abi_avoidance_test",
            ":kt_abi_avoidance_mixed_fallback_test",
        ],
    )
