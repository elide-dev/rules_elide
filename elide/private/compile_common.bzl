# SPDX-License-Identifier: Apache-2.0

"""Shared helpers for elide compile rules (Java, Kotlin, native-image)."""

load("@bazel_skylib//lib:shell.bzl", "shell")
load("@rules_java//java/common:java_common.bzl", "java_common")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("//elide:providers.bzl", "ElideInfo")
load("//elide/private:common.bzl", "collect_exported_plugins")

visibility(["//elide/..."])

TOOLCHAIN_TYPE = "//elide:toolchain_type"

# JUnit Platform ConsoleLauncher main class. Consumers must include
# `org.junit.platform:junit-platform-console-standalone` on the test classpath
# (typically as a `runtime_deps` entry) for elide_*_test rules to launch.
JUNIT_CONSOLE_LAUNCHER_MAIN = "org.junit.platform.console.ConsoleLauncher"

def _merge_java_infos(deps):
    return [d[JavaInfo] for d in deps if JavaInfo in d]

def compile_classpath(deps):
    """Merged transitive compile-time classpath from deps providing JavaInfo.

    Args:
        deps: list[Target]. Direct dependency targets.

    Returns:
        depset[File] of jars on the compile classpath.
    """
    java_infos = _merge_java_infos(deps)
    if not java_infos:
        return depset()
    return java_common.merge(java_infos).transitive_compile_time_jars

def runtime_classpath(deps, runtime_deps):
    """Merged transitive runtime classpath from deps + runtime_deps.

    Args:
        deps: list[Target]. Direct compile dependencies.
        runtime_deps: list[Target]. Runtime-only dependencies.

    Returns:
        depset[File] of jars required at runtime.
    """
    java_infos = _merge_java_infos(deps) + _merge_java_infos(runtime_deps)
    if not java_infos:
        return depset()
    return java_common.merge(java_infos).transitive_runtime_jars

def _plugin_classpath(plugins):
    java_infos = _merge_java_infos(plugins)
    if not java_infos:
        return depset()
    return java_common.merge(java_infos).transitive_runtime_jars

def run_javac(ctx, output_jar):
    """Runs `elide javac` to compile `.java` sources into `output_jar`.

    Two-action flow:
      1. `elide javac -- -d <classes_dir> -classpath <cp> <srcs>` writes
         .class files into a declared classes-dir.
      2. `elide jar -- cf <output_jar> -C <classes_dir> .` packs the
         classes-dir into the output JAR.

    Args:
        ctx: rule context. Must expose srcs/deps/javac_opts/plugins.
        output_jar: File. Declared output classes jar.
    """
    elide = ctx.toolchains[TOOLCHAIN_TYPE].elide_info
    classpath = compile_classpath(ctx.attr.deps)
    plugin_cp = _plugin_classpath(ctx.attr.plugins) if hasattr(ctx.attr, "plugins") else depset()
    sep = ctx.configuration.host_path_separator

    classes_dir = ctx.actions.declare_directory(ctx.label.name + "_classes")

    # Step 1: javac -> classes_dir/
    javac_args = ctx.actions.args()
    javac_args.add("javac")
    javac_args.add("--")
    javac_args.add("-d", classes_dir.path)
    full_cp = depset(transitive = [classpath, plugin_cp])
    javac_args.add_joined("-classpath", full_cp, join_with = sep)
    for o in ctx.attr.javac_opts:
        javac_args.add(o)
    javac_args.add_all(ctx.files.srcs)

    ctx.actions.run(
        mnemonic = "ElideJavac",
        executable = elide.binary,
        arguments = [javac_args],
        inputs = depset(direct = ctx.files.srcs, transitive = [classpath, plugin_cp, elide.tool_files]),
        outputs = [classes_dir],
        progress_message = "Compiling %{label} (elide javac)",
    )

    # Step 2: `elide jar -- cf <output> -C <classes_dir> .` packs the classes
    # directory into the output JAR rooted at the dir contents.
    jar_args = ctx.actions.args()
    jar_args.add("jar")
    jar_args.add("--")
    jar_args.add("cf")
    jar_args.add(output_jar)
    jar_args.add("-C")
    jar_args.add(classes_dir.path)
    jar_args.add(".")

    ctx.actions.run(
        mnemonic = "ElideJavacJar",
        executable = elide.binary,
        arguments = [jar_args],
        inputs = depset(direct = [classes_dir], transitive = [elide.tool_files]),
        outputs = [output_jar],
        progress_message = "Packing %{label} jar",
    )

def _friend_paths(associates):
    paths = []
    transitive = []
    for assoc in associates:
        if JavaInfo in assoc:
            jars = assoc[JavaInfo].compile_jars
            transitive.append(jars)
            for jar in jars.to_list():
                paths.append(jar.path)
    return paths, depset(transitive = transitive)

def run_kotlinc(ctx, output_jar):
    """Runs `elide kotlinc` to compile mixed `.kt`/`.java` sources into a JAR.

    kotlinc produces a JAR directly when given `-d <name>.jar`.

    Args:
        ctx: rule context. Must expose srcs/deps/kotlinc_opts/javac_opts/module_name/
            plugins/associates.
        output_jar: File. Declared output JAR (kotlinc writes it directly).
    """
    elide = ctx.toolchains[TOOLCHAIN_TYPE].elide_info
    classpath = compile_classpath(ctx.attr.deps)
    plugin_cp = _plugin_classpath(ctx.attr.plugins) if hasattr(ctx.attr, "plugins") else depset()
    friend_path_strs, friend_jars = _friend_paths(getattr(ctx.attr, "associates", []))
    sep = ctx.configuration.host_path_separator

    args = ctx.actions.args()
    args.add("kotlinc")
    args.add("--")
    args.add("-d", output_jar)
    full_cp = depset(transitive = [classpath, plugin_cp, friend_jars])
    args.add_joined("-classpath", full_cp, join_with = sep)
    if ctx.attr.module_name:
        args.add("-module-name", ctx.attr.module_name)
    if friend_path_strs:
        args.add("-Xfriend-paths=" + ",".join(friend_path_strs))
    for plugin in ctx.attr.plugins:
        for f in plugin[JavaInfo].transitive_runtime_jars.to_list():
            args.add("-Xplugin=" + f.path)
    for o in ctx.attr.kotlinc_opts:
        args.add(o)
    for o in ctx.attr.javac_opts:
        args.add("-Xjavac-arguments=" + o)
    args.add_all(ctx.files.srcs)

    ctx.actions.run(
        mnemonic = "ElideKotlinc",
        executable = elide.binary,
        arguments = [args],
        inputs = depset(
            direct = ctx.files.srcs,
            transitive = [classpath, plugin_cp, friend_jars, elide.tool_files],
        ),
        outputs = [output_jar],
        progress_message = "Compiling %{label} (elide kotlinc)",
    )

def make_java_info(ctx, output_jar, source_jar = None):
    """Builds the JavaInfo emitted by elide compile rules.

    Args:
        ctx: rule context.
        output_jar: File. Compiled classes jar.
        source_jar: File or None. Optional sources jar (sets JavaInfo.source_jar).

    Returns:
        JavaInfo carrying output_jar + ijar-derived compile jar + merged deps.
    """
    java_toolchain = ctx.toolchains["@bazel_tools//tools/jdk:toolchain_type"].java
    compile_jar = java_common.run_ijar(
        actions = ctx.actions,
        jar = output_jar,
        target_label = ctx.label,
        java_toolchain = java_toolchain,
    )
    return JavaInfo(
        output_jar = output_jar,
        compile_jar = compile_jar,
        source_jar = source_jar,
        deps = _merge_java_infos(ctx.attr.deps),
        runtime_deps = _merge_java_infos(ctx.attr.runtime_deps),
        exports = _merge_java_infos(ctx.attr.exports),
        neverlink = getattr(ctx.attr, "neverlink", False),
    )

def pack_source_jar(ctx):
    """Packs `srcs` into a sources jar via the JDK java_toolchain.

    Args:
        ctx: rule context. Must expose `srcs` and resolve the JDK toolchain.

    Returns:
        File: declared `<name>-sources.jar`.
    """
    java_toolchain = ctx.toolchains["@bazel_tools//tools/jdk:toolchain_type"].java
    source_jar = ctx.actions.declare_file(ctx.label.name + "-sources.jar")
    java_common.pack_sources(
        actions = ctx.actions,
        output_source_jar = source_jar,
        sources = ctx.files.srcs,
        java_toolchain = java_toolchain,
    )
    return source_jar

def make_elide_info(ctx):
    """Builds the ElideInfo emitted by elide compile rules.

    Propagates `exported_compiler_plugins` from `exports + exported_compiler_plugins`
    so downstream consumers transparently inherit plugin classpaths.

    Args:
        ctx: rule context.

    Returns:
        ElideInfo with propagated exported_compiler_plugins.
    """
    return ElideInfo(
        manifest = None,
        exported_compiler_plugins = collect_exported_plugins(
            ctx.attr.exports + ctx.attr.exported_compiler_plugins,
        ),
    )

_LAUNCHER_TEMPLATE_SH = """\
#!/bin/sh
set -eu
exec {elide} java -- {jvm_flags}-cp {classpath} {main_class} "$@"
"""

_LAUNCHER_TEMPLATE_BAT = """\
@echo off
"{elide}" java -- {jvm_flags}-cp "{classpath}" {main_class} %*
"""

def _is_windows(ctx):
    """Returns True when the target platform has @platforms//os:windows constraint."""
    if not hasattr(ctx.attr, "_windows_constraint"):
        return False
    constraint = ctx.attr._windows_constraint[platform_common.ConstraintValueInfo]
    return ctx.target_platform_has_constraint(constraint)

def build_launcher(ctx, output_jar):
    """Writes a shell launcher running the binary via the elide toolchain.

    Args:
        ctx: rule context.
        output_jar: File. Compiled classes jar going on the classpath.

    Returns:
        (launcher_file, runfiles) tuple.
    """
    elide = ctx.toolchains[TOOLCHAIN_TYPE].elide_info
    classpath = depset(
        direct = [output_jar],
        transitive = [runtime_classpath(ctx.attr.deps, ctx.attr.runtime_deps), elide.kotlin_stdlib_jars],
    )
    sep = ctx.configuration.host_path_separator
    classpath_str = sep.join([f.short_path for f in classpath.to_list()])
    is_win = _is_windows(ctx)
    if is_win:
        jvm_flags = "".join([f + " " for f in ctx.attr.jvm_flags])
        content = _LAUNCHER_TEMPLATE_BAT.format(
            elide = elide.binary.short_path,
            jvm_flags = jvm_flags,
            classpath = classpath_str,
            main_class = ctx.attr.main_class,
        )
        launcher = ctx.actions.declare_file(ctx.label.name + "_launcher.bat")
    else:
        jvm_flags = "".join([shell.quote(f) + " " for f in ctx.attr.jvm_flags])
        content = _LAUNCHER_TEMPLATE_SH.format(
            elide = shell.quote(elide.binary.short_path),
            jvm_flags = jvm_flags,
            classpath = shell.quote(classpath_str),
            main_class = shell.quote(ctx.attr.main_class),
        )
        launcher = ctx.actions.declare_file(ctx.label.name + "_launcher.sh")
    ctx.actions.write(output = launcher, content = content, is_executable = True)
    runfiles = ctx.runfiles(
        files = [output_jar, launcher],
        transitive_files = depset(transitive = [elide.tool_files, classpath]),
    )
    return launcher, runfiles

_TEST_LAUNCHER_TEMPLATE_SH = """\
#!/bin/sh
set -eu
# Bazel test runner contract: honour TEST_TMPDIR, XML_OUTPUT_FILE, TEST_FILTER.
reports_dir="${{TEST_TMPDIR:-/tmp}}/reports"
mkdir -p "$reports_dir"

selector_flag={selector_flag}
filter_flag=""
if [ -n "${{TEST_FILTER:-}}" ]; then
  filter_flag="--include-classname=${{TEST_FILTER}}"
fi

set +e
{elide} java -- {jvm_flags}-cp {classpath} \\
  org.junit.platform.console.ConsoleLauncher execute \\
  $selector_flag \\
  --reports-dir="$reports_dir" \\
  $filter_flag
status=$?
set -e

if [ -n "${{XML_OUTPUT_FILE:-}}" ]; then
  for f in "$reports_dir"/TEST-*.xml; do
    if [ -f "$f" ]; then
      cp "$f" "$XML_OUTPUT_FILE"
      break
    fi
  done
fi
exit $status
"""

_TEST_LAUNCHER_TEMPLATE_BAT = """\
@echo off
setlocal
if not defined TEST_TMPDIR set TEST_TMPDIR=%TEMP%
set reports_dir=%TEST_TMPDIR%\\reports
if not exist "%reports_dir%" mkdir "%reports_dir%"

set selector_flag={selector_flag}
set filter_flag=
if defined TEST_FILTER set filter_flag=--include-classname=%TEST_FILTER%

"{elide}" java -- {jvm_flags}-cp "{classpath}" org.junit.platform.console.ConsoleLauncher execute %selector_flag% --reports-dir="%reports_dir%" %filter_flag%
set status=%errorlevel%

if defined XML_OUTPUT_FILE (
  for %%f in ("%reports_dir%\\TEST-*.xml") do (
    copy "%%f" "%XML_OUTPUT_FILE%" >nul
    goto :done_copy
  )
  :done_copy
)
endlocal & exit /b %status%
"""

def build_test_launcher(ctx, output_jar):
    """Writes a JUnit Platform launcher for a test target.

    Honours Bazel's test runner contract: TEST_TMPDIR, XML_OUTPUT_FILE, and
    TEST_FILTER. Consumers must place `junit-platform-console-standalone` on
    the test classpath (typically via `runtime_deps`).

    Args:
        ctx: rule context.
        output_jar: File. Compiled classes jar going on the classpath.

    Returns:
        (launcher_file, runfiles) tuple.
    """
    elide = ctx.toolchains[TOOLCHAIN_TYPE].elide_info
    classpath = depset(
        direct = [output_jar],
        transitive = [runtime_classpath(ctx.attr.deps, ctx.attr.runtime_deps), elide.kotlin_stdlib_jars],
    )
    sep = ctx.configuration.host_path_separator
    classpath_str = sep.join([f.short_path for f in classpath.to_list()])
    is_win = _is_windows(ctx)
    selector_flag = (
        "--select-class=" + ctx.attr.test_class if ctx.attr.test_class else "--scan-classpath"
    )
    if is_win:
        jvm_flags = "".join([f + " " for f in ctx.attr.jvm_flags])
        content = _TEST_LAUNCHER_TEMPLATE_BAT.format(
            elide = elide.binary.short_path,
            jvm_flags = jvm_flags,
            classpath = classpath_str,
            selector_flag = selector_flag,
        )
        launcher = ctx.actions.declare_file(ctx.label.name + "_launcher.bat")
    else:
        jvm_flags = "".join([shell.quote(f) + " " for f in ctx.attr.jvm_flags])
        content = _TEST_LAUNCHER_TEMPLATE_SH.format(
            elide = shell.quote(elide.binary.short_path),
            jvm_flags = jvm_flags,
            classpath = shell.quote(classpath_str),
            selector_flag = shell.quote(selector_flag),
        )
        launcher = ctx.actions.declare_file(ctx.label.name + "_launcher.sh")
    ctx.actions.write(output = launcher, content = content, is_executable = True)
    runfiles = ctx.runfiles(
        files = [output_jar, launcher],
        transitive_files = depset(transitive = [elide.tool_files, classpath]),
    )
    return launcher, runfiles

# Common attribute sets used by Java and Kotlin compile rules.

COMMON_LIBRARY_ATTRS = {
    "data": attr.label_list(
        doc = "Files made available to this target's runfiles at action time.",
        allow_files = True,
    ),
    "deps": attr.label_list(
        doc = "Compile-time dependencies. Targets must provide JavaInfo.",
        providers = [[JavaInfo]],
    ),
    "exported_compiler_plugins": attr.label_list(
        doc = "Compiler plugins propagated to direct rdeps via ElideInfo (mirrors java_plugin.exported_plugins).",
        providers = [[ElideInfo]],
    ),
    "exports": attr.label_list(
        doc = "Targets re-exported to direct rdeps (transitive compile classpath).",
        providers = [[JavaInfo]],
    ),
    "neverlink": attr.bool(
        default = False,
        doc = "If true, outputs are used only for compilation, not packaged into binaries.",
    ),
    "plugins": attr.label_list(
        doc = "Compiler plugins for this compilation (only). Targets must provide JavaInfo.",
        providers = [[JavaInfo]],
    ),
    "resource_jars": attr.label_list(
        doc = "Pre-built JARs whose contents are merged into the output JAR.",
        allow_files = [".jar"],
    ),
    "resources": attr.label_list(
        doc = "Resource files packaged into the output JAR alongside compiled classes.",
        allow_files = True,
    ),
    "runtime_deps": attr.label_list(
        doc = "Runtime-only dependencies (excluded from compile classpath).",
        providers = [[JavaInfo]],
    ),
}

COMMON_BINARY_EXTRA_ATTRS = {
    "jvm_flags": attr.string_list(
        doc = "Flags passed to the JVM when running the binary.",
    ),
    "main_class": attr.string(
        doc = "Fully qualified main class.",
        mandatory = True,
    ),
    "_windows_constraint": attr.label(
        default = "@platforms//os:windows",
        providers = [[platform_common.ConstraintValueInfo]],
    ),
}

COMMON_TEST_EXTRA_ATTRS = {
    "jvm_flags": attr.string_list(
        doc = "Flags passed to the JVM when running the test.",
    ),
    "test_class": attr.string(
        doc = "Single JUnit Platform test class to select. Empty -> --scan-classpath.",
    ),
    "_windows_constraint": attr.label(
        default = "@platforms//os:windows",
        providers = [[platform_common.ConstraintValueInfo]],
    ),
}
