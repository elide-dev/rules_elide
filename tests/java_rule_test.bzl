# SPDX-License-Identifier: Apache-2.0

"""Analysis tests for elide_java_library, _binary, _test."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("//elide:providers.bzl", "ElideInfo")
load("//elide/rules:java.bzl", "elide_java_binary", "elide_java_library", "elide_java_test")

def _library_providers_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.true(env, JavaInfo in target, "must emit JavaInfo")
    asserts.true(env, ElideInfo in target, "must emit ElideInfo")
    files = target[DefaultInfo].files.to_list()
    asserts.equals(env, 1, len(files), "expected exactly one output jar")
    asserts.true(env, files[0].path.endswith(".jar"), "output must be a .jar")
    java_info = target[JavaInfo]
    asserts.false(env, any([f.basename == "kotlin-stdlib.jar" for f in java_info.transitive_runtime_jars.to_list()]), "Pure Java targets must not acquire Kotlin stdlib")
    source_jars = java_info.source_jars
    asserts.true(env, len(source_jars) > 0, "JavaInfo.source_jars must be non-empty")
    asserts.true(
        env,
        source_jars[0].basename.endswith("-sources.jar"),
        "source_jars[0] should end with -sources.jar",
    )

    # compile_jars should be ijar-derived ABI jars, distinct from the full jar.
    compile_jars = java_info.compile_jars.to_list()
    asserts.true(env, len(compile_jars) > 0, "compile_jars must be non-empty (ijar)")
    output_jar = files[0]
    asserts.true(
        env,
        compile_jars[0].path != output_jar.path,
        "compile_jars[0] must be an ijar, not the full output jar",
    )
    return analysistest.end(env)

_library_providers_test = analysistest.make(_library_providers_test_impl)

def _library_action_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    javacs = [a for a in actions if a.mnemonic == "ElideJavac"]
    asserts.equals(env, 1, len(javacs), "expected one ElideJavac action")
    asserts.false(env, any(["/lib/llvm/" in f.path for f in javacs[0].inputs.to_list()]), "JVM compilation must not carry the LLVM toolchain")
    asserts.false(env, any(["/lib/static/" in f.path for f in javacs[0].inputs.to_list()]), "JVM compilation must not carry native-linking static libraries")
    argv = javacs[0].argv
    asserts.true(env, "javac" in argv, "expected `javac` subcommand in argv")

    # Single-action `--jar` flow (Elide 1.3.1): one `elide javac --jar <jar> --
    # -classpath <cp> <srcs>` action writes the output jar directly. The worker
    # now accepts the leading `--` (and parses `--jar` before it), so worker and
    # one-shot share the same arg form. Bazel injects `--persistent_worker` when
    # it spawns the worker, so the rule must not pass it.
    asserts.false(
        env,
        "--persistent_worker" in argv,
        "rule must not pass `--persistent_worker`; Bazel injects it for workers",
    )
    asserts.true(env, "--jar" in argv, "expected `--jar <output>` leading Elide option")
    asserts.true(env, "--" in argv, "expected the `--` separator before bare TOOL_ARGS")
    asserts.true(env, "-classpath" in argv, "expected `-classpath` flag passed to javac")
    asserts.true(
        env,
        len([a for a in argv if a.endswith(".java")]) >= 1,
        "expected `.java` srcs in argv",
    )
    jars = [a for a in actions if a.mnemonic == "ElideJavacJar"]
    asserts.equals(env, 0, len(jars), "no separate ElideJavacJar action (collapsed into --jar)")
    asserts.false(env, "--classpath-cache" in argv, "--classpath-cache must be off by default")
    asserts.false(env, "-proc:none" in argv, "default processing behavior must remain unchanged")
    asserts.equals(
        env,
        "1",
        javacs[0].env.get("ELIDE_BAZEL", ""),
        "ElideJavac must run with ELIDE_BAZEL=1 (Bazel signal for elide output; WHIPLASH#1131)",
    )
    return analysistest.end(env)

_library_action_test = analysistest.make(_library_action_test_impl)

def _abi_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    headers = [a for a in actions if a.mnemonic == "ElideJavacAbi"]
    asserts.equals(env, 1, len(headers))
    header = headers[0]
    asserts.true(env, header.argv.index("--abi-only") < header.argv.index("--"))
    asserts.true(env, "--jar" in header.argv)
    info = analysistest.target_under_test(env)[JavaInfo]
    asserts.equals(env, header.outputs.to_list(), info.compile_jars.to_list())
    asserts.false(env, any([a.mnemonic == "JavaIjar" for a in actions]))
    asserts.true(env, any([a.mnemonic == "ElideJavac" for a in actions]))
    asserts.false(env, any([f.basename.endswith("_abi.jar") for f in info.transitive_runtime_jars.to_list()]))
    return analysistest.end(env)

_abi_test = analysistest.make(
    _abi_test_impl,
    config_settings = {"@@//config/javac:abi_compile_avoidance": True},  # buildifier: disable=canonical-repository
)

_abi_no_worker_test = analysistest.make(
    _abi_test_impl,
    config_settings = {
        "@@//config/javac:abi_compile_avoidance": True,  # buildifier: disable=canonical-repository
        "@@//elide:use_workers": False,  # buildifier: disable=canonical-repository
    },
)

def _abi_fallback_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    asserts.false(env, any([a.mnemonic == "ElideJavacAbi" for a in actions]))
    info = analysistest.target_under_test(env)[JavaInfo]
    asserts.false(env, any([f.basename.endswith("_abi.jar") for f in info.compile_jars.to_list()]))
    return analysistest.end(env)

_abi_fallback_test = analysistest.make(
    _abi_fallback_test_impl,
    config_settings = {"@@//config/javac:abi_compile_avoidance": True},  # buildifier: disable=canonical-repository
)

def _fused_abi_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    asserts.false(env, any([a.mnemonic == "ElideJavacAbi" for a in actions]))
    compile = [a for a in actions if a.mnemonic == "ElideJavac"][0]
    asserts.true(env, compile.argv.index("--emit-abi") < compile.argv.index("--"))
    headers = [f for f in compile.outputs.to_list() if f.basename.endswith("_abi.jar")]
    asserts.equals(env, 1, len(headers))
    info = analysistest.target_under_test(env)[JavaInfo]
    asserts.equals(env, headers, info.compile_jars.to_list())
    asserts.false(env, any([f in headers for f in info.transitive_runtime_jars.to_list()]))
    return analysistest.end(env)

_FUSED_SETTINGS = {
    "@@//config/javac:abi_compile_avoidance": True,  # buildifier: disable=canonical-repository
    "@@//config/javac:abi_from_compile": True,  # buildifier: disable=canonical-repository
}
_fused_abi_test = analysistest.make(_fused_abi_test_impl, config_settings = _FUSED_SETTINGS)
_fused_no_worker_test = analysistest.make(
    _fused_abi_test_impl,
    config_settings = dict(_FUSED_SETTINGS, **{"@@//elide:use_workers": False}),  # buildifier: disable=canonical-repository
)
_fused_fallback_test = analysistest.make(_abi_fallback_test_impl, config_settings = _FUSED_SETTINGS)
_fused_disabled_test = analysistest.make(
    _abi_fallback_test_impl,
    config_settings = {"@@//config/javac:abi_from_compile": True},  # buildifier: disable=canonical-repository
)

def _classpath_cache_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    javacs = [a for a in actions if a.mnemonic == "ElideJavac"]
    asserts.equals(env, 1, len(javacs), "expected one ElideJavac action")
    argv = javacs[0].argv
    asserts.true(
        env,
        "--classpath-cache" in argv,
        "--classpath-cache must be passed when //config/javac:classpath_cache=True",
    )

    # `--classpath-cache` is an Elide option, so it must precede the `--` separator.
    asserts.true(
        env,
        argv.index("--classpath-cache") < argv.index("--"),
        "--classpath-cache must come before the `--` separator",
    )
    asserts.true(env, "-proc:none" in argv, "processor-free cache requests must be eligible for reuse")
    asserts.true(env, argv.index("-proc:none") > argv.index("--"))
    return analysistest.end(env)

def _classpath_cache_processor_test_impl(ctx):
    env = analysistest.begin(ctx)
    javac = [a for a in analysistest.target_actions(env) if a.mnemonic == "ElideJavac"][0]
    asserts.true(env, "--classpath-cache" in javac.argv)
    asserts.false(env, "-proc:none" in javac.argv, "cache opt-in must not suppress configured processors")
    return analysistest.end(env)

_classpath_cache_processor_test = analysistest.make(
    _classpath_cache_processor_test_impl,
    config_settings = {"@@//config/javac:classpath_cache": True},  # buildifier: disable=canonical-repository
)

_classpath_cache_test = analysistest.make(
    _classpath_cache_test_impl,
    # See _library_action_no_worker_test re: the @@ canonical root ref.
    config_settings = {"@@//config/javac:classpath_cache": True},  # buildifier: disable=canonical-repository
)

def _library_action_no_worker_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    javacs = [a for a in actions if a.mnemonic == "ElideJavac"]
    asserts.equals(env, 1, len(javacs), "expected one ElideJavac action")
    argv = javacs[0].argv
    asserts.true(env, "javac" in argv, "expected `javac` subcommand in argv")

    # Workers off (`--@rules_elide//elide:use_workers=false`): one-shot
    # `elide javac --jar <jar> -- <TOOL_ARGS>`, so `--jar` and the `--`
    # separator the top-level parser expects must be present.
    asserts.true(env, "--jar" in argv, "one-shot mode must pass the `--jar` option")
    asserts.true(env, "--" in argv, "one-shot mode must pass the `--` separator")
    return analysistest.end(env)

_library_action_no_worker_test = analysistest.make(
    _library_action_no_worker_test_impl,
    # analysis_test_transition resolves these labels from bazel_skylib's context,
    # where neither //elide nor @rules_elide is visible; the canonical root ref
    # (@@, this module when it is the root) is the only form that resolves.
    config_settings = {"@@//elide:use_workers": False},  # buildifier: disable=canonical-repository
)

def _binary_executable_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.true(env, JavaInfo in target, "must emit JavaInfo")
    asserts.true(env, ElideInfo in target, "must emit ElideInfo")
    info = target[DefaultInfo]
    asserts.true(env, info.files_to_run.executable != None, "binary must be executable")
    asserts.true(
        env,
        info.files_to_run.executable.basename.endswith("_launcher.sh"),
        "launcher file must use `_launcher.sh` suffix (avoids collision with .jar)",
    )
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
        name = "_dep_lib_fixture",
        srcs = [":_hello_src"],
        testonly = True,
        tags = ["manual"],
    )
    elide_java_library(
        name = "_lib_fixture",
        srcs = [":_hello_src"],
        deps = [":_dep_lib_fixture"],
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
    elide_java_test(
        name = "_test_fixture",
        srcs = [":_hello_src"],
        test_class = "Hello",
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
    _library_action_no_worker_test(
        name = "library_action_no_worker_test",
        target_under_test = ":_lib_fixture",
    )
    _classpath_cache_test(
        name = "library_classpath_cache_test",
        target_under_test = ":_lib_fixture",
    )
    _binary_executable_test(
        name = "binary_executable_test",
        target_under_test = ":_bin_fixture",
    )
    _test_rule_executable_test(
        name = "test_rule_executable_test",
        target_under_test = ":_test_fixture",
    )
    for kind in ["lib", "bin", "test"]:
        _fused_abi_test(name = "java_fused_" + kind + "_test", target_under_test = ":_" + kind + "_fixture")
        _abi_test(
            name = "java_abi_" + kind + "_test",
            target_under_test = ":_" + kind + "_fixture",
        )
    _abi_no_worker_test(
        name = "java_abi_no_worker_test",
        target_under_test = ":_lib_fixture",
    )
    elide_java_library(
        name = "_processor_fixture",
        srcs = [":_hello_src"],
        javac_opts = ["-processor", "example.Processor"],
        testonly = True,
        tags = ["manual"],
    )
    _abi_fallback_test(
        name = "java_abi_processor_fallback_test",
        target_under_test = ":_processor_fixture",
    )
    for kind, attrs in [
        ("plugin", {"plugins": [":_dep_lib_fixture"]}),
        ("resource_jar", {"resource_jars": [":_dep_lib_fixture"]}),
    ]:
        elide_java_library(
            name = "_abi_" + kind + "_fixture",
            srcs = [":_hello_src"],
            testonly = True,
            tags = ["manual"],
            **attrs
        )
        _abi_fallback_test(
            name = "java_abi_" + kind + "_fallback_test",
            target_under_test = ":_abi_" + kind + "_fixture",
        )
    _fused_no_worker_test(name = "java_fused_no_worker_test", target_under_test = ":_lib_fixture")
    _fused_disabled_test(name = "java_fused_disabled_test", target_under_test = ":_lib_fixture")
    _fused_fallback_test(name = "java_fused_processor_fallback_test", target_under_test = ":_processor_fixture")
    for kind in ["plugin", "resource_jar"]:
        _fused_fallback_test(name = "java_fused_" + kind + "_fallback_test", target_under_test = ":_abi_" + kind + "_fixture")
    for kind, target in [("explicit", ":_processor_fixture"), ("plugin", ":_abi_plugin_fixture")]:
        _classpath_cache_processor_test(name = "java_cache_" + kind + "_test", target_under_test = target)
    native.test_suite(
        name = name,
        tests = [
            ":java_fused_lib_test",
            ":java_fused_bin_test",
            ":java_fused_test_test",
            ":java_fused_no_worker_test",
            ":java_fused_disabled_test",
            ":java_fused_processor_fallback_test",
            ":java_fused_plugin_fallback_test",
            ":java_fused_resource_jar_fallback_test",
            ":java_abi_lib_test",
            ":java_abi_plugin_fallback_test",
            ":java_abi_resource_jar_fallback_test",
            ":java_abi_bin_test",
            ":java_abi_test_test",
            ":java_abi_no_worker_test",
            ":java_abi_processor_fallback_test",
            ":library_providers_test",
            ":library_action_test",
            ":library_action_no_worker_test",
            ":library_classpath_cache_test",
            ":java_cache_explicit_test",
            ":java_cache_plugin_test",
            ":binary_executable_test",
            ":test_rule_executable_test",
        ],
    )
