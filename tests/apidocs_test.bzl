# SPDX-License-Identifier: Apache-2.0
"""Analysis coverage for elide_apidocs."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("//elide:defs.bzl", "elide_apidocs")

def _fake_java_impl(ctx):
    return [JavaInfo(
        output_jar = ctx.file.jar,
        compile_jar = ctx.file.jar,
        source_jar = ctx.file.source_jar,
        generated_source_jar = ctx.file.generated_source_jar,
    )]

# A JavaInfo whose generated sources are in a separate jar, as elide javac and
# other rules (but not rules_java) report them.
_fake_java = rule(
    implementation = _fake_java_impl,
    attrs = {
        "generated_source_jar": attr.label(allow_single_file = True),
        "jar": attr.label(allow_single_file = True, mandatory = True),
        "source_jar": attr.label(allow_single_file = True),
    },
)

def _apidocs_action(env):
    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "ElideApiDocs"]
    asserts.equals(env, 1, len(actions))
    return actions[0] if actions else None

def _basenames(files):
    return [f.basename for f in files.to_list()]

def _apidocs_test_impl(ctx):
    env = analysistest.begin(ctx)
    action = _apidocs_action(env)
    if action:
        argv = action.argv
        for flag in ctx.attr.flags:
            asserts.true(env, flag in argv, "missing argument " + flag)
        for flag in ctx.attr.absent_flags:
            asserts.false(env, flag in argv, "unexpected argument " + flag)
        for pair in ctx.attr.pairs:
            first, second = pair.split("=", 1)
            found = [i for i in range(len(argv) - 1) if argv[i] == first and argv[i + 1].endswith(second)]
            asserts.true(env, len(found) > 0, "missing " + first + " " + second)
        inputs = _basenames(action.inputs)
        for name in ctx.attr.input_names:
            asserts.true(env, name in inputs, "undeclared input " + name)
        for name in ctx.attr.absent_inputs:
            asserts.false(env, name in inputs, "unexpected input " + name)
        asserts.true(env, [a for a in argv if a.endswith("/ApiDocs.java")] != [], "the action program is missing")
        asserts.true(env, argv[0].endswith("/bin/java"), "javadoc must run on the selected JDK: " + argv[0])

        # The registered Elide toolchain's binary (the stub or a downloaded release), declared as an input.
        runtime = action.env.get("APIDOCS_JS_RUNTIME", "")
        asserts.true(env, runtime.split("/")[-1] in ["elide", "_test_stub_elide_bin"], "the JS runtime is not an Elide binary: " + runtime)
        asserts.true(env, runtime in [f.path for f in action.inputs.to_list()], "the Elide binary is not an action input")
        asserts.false(env, "PATH" in action.env, "the action must not depend on PATH")
        outputs = _basenames(action.outputs)
        name = analysistest.target_under_test(env).label.name
        asserts.true(env, name + "_site" in outputs, "missing site directory")
        asserts.true(env, name + ".tar.gz" in outputs, "missing archive")
    target = analysistest.target_under_test(env)
    groups = target[OutputGroupInfo]
    asserts.equals(env, 1, len(groups.apidocs_site.to_list()))
    asserts.equals(env, 1, len(groups.apidocs_archive.to_list()))
    return analysistest.end(env)

_apidocs_test = analysistest.make(
    _apidocs_test_impl,
    attrs = {
        "absent_flags": attr.string_list(),
        "absent_inputs": attr.string_list(),
        "flags": attr.string_list(),
        "input_names": attr.string_list(),
        "pairs": attr.string_list(doc = "FLAG=VALUE: FLAG followed by an argument ending in VALUE."),
    },
)

def _invalid_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, ctx.attr.message)
    return analysistest.end(env)

_invalid_test = analysistest.make(
    _invalid_test_impl,
    expect_failure = True,
    attrs = {"message": attr.string()},
)

def apidocs_test_suite(name):
    """Defines elide_apidocs analysis fixtures and tests.

    Args:
        name: Test suite name.
    """
    common = {"tags": ["manual"], "testonly": True}
    for file in ["api.jar", "api-src.jar", "api-gensrc.jar", "doclet.jar", "theme.json", "element-list", "jdk.list", "other.list", "overview.html"]:
        write_file(name = "_apidocs_" + file, out = "apidocs_fixture/" + file, content = ["analysis-only fixture"], **common)
    _fake_java(
        name = "_apidocs_api",
        jar = ":_apidocs_api.jar",
        source_jar = ":_apidocs_api-src.jar",
        generated_source_jar = ":_apidocs_api-gensrc.jar",
        **common
    )
    _fake_java(name = "_apidocs_no_sources", jar = ":_apidocs_api.jar", **common)

    elide_apidocs(
        name = "_apidocs_full",
        deps = [":_apidocs_api"],
        doclet = ":_apidocs_doclet.jar",
        packages = ["com.example.api", "com.example.spi"],
        exclude_packages = ["com.example.api.internal"],
        title = "Example API",
        module_name = "example",
        version = "1.2.3",
        theme = ":_apidocs_theme.json",
        source_ref = "abc123",
        problems = "error,inheritdoc=warning",
        links = ["https://example.com/online/"],
        offline_links = {
            "https://docs.oracle.com/en/java/javase/25/docs/api/": ":_apidocs_element-list",
            "https://example.com/other/": ":_apidocs_other.list",
        },
        data = [":_apidocs_overview.html"],
        javadoc_opts = ["-overview", "$(location :_apidocs_overview.html)", "-quiet"],
        jvm_flags = ["-Xmx2g"],
        **common
    )
    _apidocs_test(
        name = "apidocs_full_test",
        target_under_test = ":_apidocs_full",
        flags = ["-quiet", "-Xmx2g"],
        pairs = [
            "--srcjar=tests/apidocs_fixture/api-src.jar",
            "--srcjar=tests/apidocs_fixture/api-gensrc.jar",
            "--package=com.example.api",
            "--package=com.example.spi",
            "--exclude=com.example.api.internal",
            "--doclet=dev.elide.doclet.ElideDoclet",
            "--docletpath=tests/apidocs_fixture/doclet.jar",
            "--classpath=tests/apidocs_fixture/api.jar",
            "-doctitle=Example API",
            "-windowtitle=Example API",
            "--module-name=example",
            "--module-version=1.2.3",
            "--theme=tests/apidocs_fixture/theme.json",
            "--source-ref=abc123",
            "--problems=error,inheritdoc=warning",
            "-link=https://example.com/online/",
            "-linkoffline=https://docs.oracle.com/en/java/javase/25/docs/api/",
            "-overview=tests/apidocs_fixture/overview.html",
        ],
        input_names = ["api-src.jar", "api-gensrc.jar", "api.jar", "doclet.jar", "theme.json", "element-list", "overview.html", "ApiDocs.java", "java"],
    )

    # Optional doclet options are left out, so other doclets do not see unknown options.
    elide_apidocs(
        name = "_apidocs_minimal",
        deps = [":_apidocs_api"],
        doclet = ":_apidocs_doclet.jar",
        doclet_class = "com.example.OtherDoclet",
        generated_sources = False,
        **common
    )
    _apidocs_test(
        name = "apidocs_minimal_test",
        target_under_test = ":_apidocs_minimal",
        pairs = ["--doclet=com.example.OtherDoclet"],
        absent_flags = ["--theme", "--module-name", "--module-version", "--source-ref", "--problems", "-doctitle", "--package", "-linkoffline"],
        absent_inputs = ["api-gensrc.jar"],
        input_names = ["api-src.jar"],
    )

    elide_apidocs(name = "_apidocs_empty", deps = [":_apidocs_no_sources"], doclet = ":_apidocs_doclet.jar", **common)
    _invalid_test(name = "apidocs_no_sources_test", target_under_test = ":_apidocs_empty", message = "deps provide no source jars")

    native.filegroup(name = "_apidocs_two_lists", srcs = [":_apidocs_jdk.list", ":_apidocs_other.list"], **common)
    elide_apidocs(
        name = "_apidocs_bad_link",
        deps = [":_apidocs_api"],
        doclet = ":_apidocs_doclet.jar",
        offline_links = {"https://example.com/": ":_apidocs_two_lists"},
        **common
    )
    _invalid_test(name = "apidocs_bad_link_test", target_under_test = ":_apidocs_bad_link", message = "must be one element-list file")

    native.test_suite(
        name = name,
        tests = [
            ":apidocs_bad_link_test",
            ":apidocs_full_test",
            ":apidocs_minimal_test",
            ":apidocs_no_sources_test",
        ],
    )
