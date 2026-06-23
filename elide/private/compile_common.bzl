# SPDX-License-Identifier: Apache-2.0

"""Shared helpers for elide compile rules (Java, Kotlin, native-image)."""

load("@bazel_skylib//lib:shell.bzl", "shell")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
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

def _has_exported_processors(deps):
    for d in deps:
        if JavaInfo in d and d[JavaInfo].plugins.processor_classes.to_list():
            return True
    return False

def _has_packaged_resources(ctx):
    return bool(ctx.files.resources) or bool(ctx.files.resource_jars)

def _resource_jar_path(file, strip_prefix):
    path = file.short_path
    if not strip_prefix:
        return path
    prefix = strip_prefix if strip_prefix.endswith("/") else strip_prefix + "/"
    if not path.startswith(prefix):
        fail("resource %s is not under resource_strip_prefix %r" % (path, strip_prefix))
    return path[len(prefix):]

def _merge_resources(ctx, class_jars, output_jar):
    java_toolchain = ctx.toolchains["@bazel_tools//tools/jdk:toolchain_type"].java
    strip_prefix = getattr(ctx.attr, "resource_strip_prefix", "")
    resources = ctx.files.resources
    resource_jars = ctx.files.resource_jars

    args = ctx.actions.args()
    args.add("--output", output_jar)
    args.add("--normalize")
    args.add("--exclude_build_data")
    if class_jars or resource_jars:
        args.add("--sources")
        args.add_all(class_jars)
        args.add_all(resource_jars)
    if resources:
        args.add("--resources")
        for f in resources:
            args.add("%s:%s" % (f.path, _resource_jar_path(f, strip_prefix)))

    ctx.actions.run(
        mnemonic = "ElideResourceJar",
        executable = java_toolchain.single_jar,
        arguments = [args],
        inputs = depset(direct = class_jars + resources + resource_jars),
        outputs = [output_jar],
        progress_message = "Packing %{label} jar",
    )

# Execution requirements opting compile actions into Bazel persistent workers.
# Elide's embedded javac/kotlinc workers speak the length-delimited protobuf
# WorkRequest protocol, so we advertise `proto`. Multiplex workers are verified
# working in Elide 1.3.1 (one process serves concurrent WorkRequests with
# isolated, correct outputs — WHIPLASH #1004), so we advertise
# `supports-multiplex-workers`. Bazel uses workers by default for actions
# carrying these tags; users retain the standard kill-switches
# (`--strategy=ElideJavac=local`, `--worker_max_instances=0`).
_WORKER_EXEC_REQUIREMENTS = {
    "requires-worker-protocol": "proto",
    "supports-multiplex-workers": "1",
    "supports-workers": "1",
}

# Signals to elide that it is running under Bazel, so it can adjust output
# (suppress emoji/decorative status lines, drop color, project-relative paths,
# `[warning]`-prefix diagnostics) — Elide-side, tracked in WHIPLASH#1131. Set on
# elide compile actions; reaches persistent workers too (it is part of the
# action env, not the scrubbed ambient env).
_ELIDE_BAZEL_ENV = {"ELIDE_BAZEL": "1"}

def _tool_args(ctx):
    """Begins a buffer for a compile action's tool args.

    Holds the args destined for the embedded tool (javac/kotlinc), including
    any leading Elide options (e.g. `--jar`) and the `--` separator that
    precedes the bare TOOL_ARGS. Callers are responsible for adding `--`
    themselves; `_run_elide_compile` delivers this buffer verbatim, deciding
    only how it is transported (worker params-file WorkRequest vs one-shot
    inline).
    """
    return ctx.actions.args()

def _run_elide_compile(ctx, mnemonic, subcommand, tool_args, inputs, outputs, progress_message):
    """Runs `elide <subcommand>` to compile, as a worker or a one-shot process.

    Both modes use the same arg form: `elide <subcommand> <tool_args>`, where
    `tool_args` already carries any leading Elide options and the `--`
    separator (callers add these). As of Elide 1.3.1 the persistent worker
    accepts the leading `--` (it rejected it in 1.3.0) and parses Elide options
    like `--jar`, so worker and one-shot share one arg form.

    Selected by the `//elide:use_workers` build setting:

    - workers on (default): the action advertises `supports-workers`; Bazel
      appends `--persistent_worker` when it spawns the reusable process and
      delivers `tool_args` as a multiline params-file WorkRequest.
    - workers off: a one-shot `elide <subcommand> <tool_args>` process per
      target, with `tool_args` delivered inline. This is the supported way to
      compile without workers (the Bazel-native worker-off path,
      `elide <tool> @flagfile`, is broken upstream — WHIPLASH #994).

    Args:
        ctx: rule context.
        mnemonic: str. Action mnemonic (also the worker pool key).
        subcommand: str. Elide compile subcommand, e.g. `javac` or `kotlinc`.
        tool_args: Args. Tool args from `_tool_args` (incl. `--` separator).
        inputs: depset[File]. Action inputs.
        outputs: list[File]. Declared action outputs.
        progress_message: str. Bazel progress message.
    """
    elide = ctx.toolchains[TOOLCHAIN_TYPE].elide_info
    lead = ctx.actions.args()
    lead.add(subcommand)

    if ctx.attr._use_workers[BuildSettingInfo].value:
        tool_args.use_param_file("@%s", use_always = True)
        tool_args.set_param_file_format("multiline")
        ctx.actions.run(
            mnemonic = mnemonic,
            executable = elide.binary,
            arguments = [lead, tool_args],
            inputs = inputs,
            outputs = outputs,
            progress_message = progress_message,
            execution_requirements = _WORKER_EXEC_REQUIREMENTS,
            env = _ELIDE_BAZEL_ENV,
        )
    else:
        ctx.actions.run(
            mnemonic = mnemonic,
            executable = elide.binary,
            arguments = [lead, tool_args],
            inputs = inputs,
            outputs = outputs,
            progress_message = progress_message,
            env = _ELIDE_BAZEL_ENV,
        )

def run_javac(ctx, output_jar):
    """Runs `elide javac --jar` to compile `.java` sources into `output_jar`.

    Single-action flow: `elide javac --jar <jar> -- -classpath <cp> <srcs>`
    compiles and writes the output JAR directly (verified against Elide 1.3.1;
    `--jar` alone produces the jar, no `-d` scratch dir needed). `--jar`
    requires the `--` separator that precedes the bare javac TOOL_ARGS.

    When the target carries packaged resources, `--jar` writes an intermediate
    class jar which `_merge_resources` then folds into `output_jar`; otherwise
    `--jar` writes `output_jar` directly.

    Args:
        ctx: rule context. Must expose srcs/deps/javac_opts/plugins.
        output_jar: File. Declared output classes jar.
    """
    elide = ctx.toolchains[TOOLCHAIN_TYPE].elide_info
    classpath = compile_classpath(ctx.attr.deps)
    plugin_cp = _plugin_classpath(ctx.attr.plugins) if hasattr(ctx.attr, "plugins") else depset()
    sep = ctx.configuration.host_path_separator

    has_res = _has_packaged_resources(ctx)
    class_jar = ctx.actions.declare_file(ctx.label.name + "_classes.jar") if has_res else output_jar

    # `elide javac --jar <class_jar> [--classpath-cache] -- -classpath <cp> <javac_opts> <srcs>`.
    javac_args = _tool_args(ctx)
    javac_args.add("--jar", class_jar)
    if ctx.attr._classpath_cache[BuildSettingInfo].value:
        javac_args.add("--classpath-cache")
    javac_args.add("--")
    full_cp = depset(transitive = [classpath, plugin_cp])
    javac_args.add_joined("-classpath", full_cp, join_with = sep)
    for o in ctx.attr.javac_opts:
        javac_args.add(o)
    javac_args.add_all(ctx.files.srcs)

    _run_elide_compile(
        ctx,
        mnemonic = "ElideJavac",
        subcommand = "javac",
        tool_args = javac_args,
        inputs = depset(direct = ctx.files.srcs, transitive = [classpath, plugin_cp, elide.compile_tool_files]),
        outputs = [class_jar],
        progress_message = "Compiling %{label} (elide javac)",
    )

    if has_res:
        _merge_resources(ctx, [class_jar], output_jar)

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
    """Compiles mixed `.kt`/`.java` sources into `output_jar`.

    Args:
        ctx: rule context. Must expose srcs/deps/kotlinc_opts/javac_opts/module_name/
            plugins/associates.
        output_jar: File. Declared output JAR.
    """
    elide = ctx.toolchains[TOOLCHAIN_TYPE].elide_info
    classpath = compile_classpath(ctx.attr.deps)
    plugin_cp = _plugin_classpath(ctx.attr.plugins) if hasattr(ctx.attr, "plugins") else depset()
    friend_path_strs, friend_jars = _friend_paths(getattr(ctx.attr, "associates", []))
    sep = ctx.configuration.host_path_separator

    kt_srcs = [f for f in ctx.files.srcs if f.extension == "kt"]
    java_srcs = [f for f in ctx.files.srcs if f.extension == "java"]
    has_kt = bool(kt_srcs)
    has_java = bool(java_srcs)
    has_res = _has_packaged_resources(ctx)

    single_kt_only = has_kt and not has_java and not has_res

    # Incremental compilation (opt-in via //config/kotlinc:incremental). kotlinc IC tracks
    # per-class files, so it requires a classes *directory* output (`-d <dir>`),
    # not a jar. When enabled we compile to a tree-artifact dir with a stable,
    # per-target, undeclared cache dir, then pack the dir into `kt_jar` below.
    incremental = ctx.attr._incremental[BuildSettingInfo].value and has_kt

    kt_jar = None
    if has_kt:
        kt_jar = output_jar if single_kt_only else ctx.actions.declare_file(ctx.label.name + "_kotlin_classes.jar")

        # In IC mode kotlinc writes classes here and `kt_jar` is produced by a
        # follow-on pack action; otherwise kotlinc writes `kt_jar` directly.
        kt_classes = ctx.actions.declare_directory(ctx.label.name + "_kt_classes") if incremental else None
        compile_out = kt_classes if incremental else kt_jar

        args = _tool_args(ctx)
        if incremental:
            # Undeclared worker-scoped scratch (sibling of the classes dir);
            # relative to the worker cwd (exec root), so it persists across
            # persistent-worker requests when unsandboxed. Elide options precede
            # the `--` separator (same slot as --report-used-deps).
            args.add("--incremental")
            args.add("--incremental-cache-dir", kt_classes.path + "_iccache")

        # Builtin compiler plugins enabled by name (elide option, before `--`).
        # Forces the named plugins on — robust for plugins the classpath
        # heuristic may miss (notably Metro). Exclusion of unlisted-but-detected
        # plugins is not yet fully honored upstream (WHIPLASH#1119).
        builtin_plugins = getattr(ctx.attr, "builtin_plugins", [])
        if builtin_plugins:
            args.add_joined(builtin_plugins, join_with = ",", format_joined = "--plugins=%s")
        args.add("--")

        # A directory output must be passed as a plain path (Args#add rejects
        # directory Files); a jar output is a regular File.
        args.add("-d", compile_out.path if incremental else compile_out)
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

        _run_elide_compile(
            ctx,
            mnemonic = "ElideKotlinc",
            subcommand = "kotlinc",
            tool_args = args,
            inputs = depset(
                direct = ctx.files.srcs,
                transitive = [classpath, plugin_cp, friend_jars, elide.compile_tool_files],
            ),
            outputs = [compile_out],
            progress_message = "Compiling %{label} (elide kotlinc)",
        )

        # IC compiled to a directory; pack it into `kt_jar` (the form the rest of
        # the pipeline — resource merge, JavaInfo — expects). One-shot, not a
        # worker: `elide jar -- --create --file <jar> -C <classesdir> .`.
        if incremental:
            pack = ctx.actions.args()
            pack.add("jar")
            pack.add("--")
            pack.add("--create")
            pack.add("--file", kt_jar)
            pack.add("-C", kt_classes.path)
            pack.add(".")
            ctx.actions.run(
                mnemonic = "ElideKotlincPack",
                executable = elide.binary,
                arguments = [pack],
                inputs = depset(direct = [kt_classes], transitive = [elide.compile_tool_files]),
                outputs = [kt_jar],
                progress_message = "Packing %{label} (elide jar)",
                env = _ELIDE_BAZEL_ENV,
            )

    if single_kt_only:
        return

    class_jars = []
    if has_kt:
        class_jars.append(kt_jar)
    if has_java:
        class_jars.append(_compile_java_aux(ctx, java_srcs, kt_jar))

    _merge_resources(ctx, class_jars, output_jar)

def _compile_java_aux(ctx, java_srcs, kt_jar):
    if _has_exported_processors(ctx.attr.deps):
        return _compile_java_processed(ctx, java_srcs, kt_jar)

    elide = ctx.toolchains[TOOLCHAIN_TYPE].elide_info
    classpath = compile_classpath(ctx.attr.deps)
    plugin_cp = _plugin_classpath(ctx.attr.plugins) if hasattr(ctx.attr, "plugins") else depset()
    sep = ctx.configuration.host_path_separator

    java_jar = ctx.actions.declare_file(ctx.label.name + "_java_classes.jar")
    kt_jars = [kt_jar] if kt_jar else []
    full_cp = depset(direct = kt_jars, transitive = [classpath, plugin_cp, elide.kotlin_stdlib_jars])

    # `elide javac --jar <java_jar> [--classpath-cache] -- -classpath <cp> -proc:none <javac_opts> <srcs>`.
    javac_args = _tool_args(ctx)
    javac_args.add("--jar", java_jar)
    if ctx.attr._classpath_cache[BuildSettingInfo].value:
        javac_args.add("--classpath-cache")
    javac_args.add("--")
    javac_args.add_joined("-classpath", full_cp, join_with = sep)
    javac_args.add("-proc:none")
    for o in ctx.attr.javac_opts:
        javac_args.add(o)
    javac_args.add_all(java_srcs)

    _run_elide_compile(
        ctx,
        mnemonic = "ElideKotlinJavac",
        subcommand = "javac",
        tool_args = javac_args,
        inputs = depset(
            direct = java_srcs + kt_jars,
            transitive = [classpath, plugin_cp, elide.kotlin_stdlib_jars, elide.compile_tool_files],
        ),
        outputs = [java_jar],
        progress_message = "Compiling %{label} java sources (elide javac)",
    )
    return java_jar

def _compile_java_processed(ctx, java_srcs, kt_jar):
    elide = ctx.toolchains[TOOLCHAIN_TYPE].elide_info
    java_toolchain = ctx.toolchains["@bazel_tools//tools/jdk:toolchain_type"].java
    java_jar = ctx.actions.declare_file(ctx.label.name + "_java_classes.jar")

    extra_jars = ([kt_jar] if kt_jar else []) + elide.kotlin_stdlib_jars.to_list()
    extra_deps = [JavaInfo(output_jar = j, compile_jar = j) for j in extra_jars]

    java_common.compile(
        ctx,
        source_files = java_srcs,
        output = java_jar,
        java_toolchain = java_toolchain,
        deps = _merge_java_infos(ctx.attr.deps) + _merge_java_infos(getattr(ctx.attr, "plugins", [])) + extra_deps,
        javac_opts = ctx.attr.javac_opts,
        strict_deps = "OFF",
    )
    return java_jar

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

# Canonical Bazel bash runfiles library boilerplate (v3). Resolves runfiles in
# both directory- and manifest-based layouts. We need rlocation (rather than raw
# short_paths) so the launcher works in BOTH invocation modes:
#   * `bazel run`, where the cwd is the runfiles tree, AND
#   * as a persistent worker (e.g. when used as a rules_kotlin KotlinBuilder),
#     where Bazel runs from the execroot and runfiles short_paths do not resolve.
# https://github.com/bazelbuild/bazel/blob/master/tools/bash/runfiles/runfiles.bash
_RUNFILES_INIT = """\
# --- begin runfiles.bash initialization v3 ---
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \\
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \\
  source "$0.runfiles/$f" 2>/dev/null || \\
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \\
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \\
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---
"""

_LAUNCHER_TEMPLATE_SH = """\
#!/usr/bin/env bash
{runfiles_init}
cp=""
for entry in {classpath}; do
  abs="$(rlocation "$entry")"
  if [ -z "$cp" ]; then cp="$abs"; else cp="$cp{sep}$abs"; fi
done
exec "$(rlocation {elide})" java -- {jvm_flags}-cp "$cp" {main_class} "$@"
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

def _rlocation_path(ctx, file):
    """Maps a File's runfiles-relative short_path to its `rlocation` key.

    Repository-rooted short_paths (`../<repo>/...`) are normalized to the
    canonical `<repo>/...` rlocation form; main-repo paths are prefixed with the
    workspace name.
    """
    sp = file.short_path
    if sp.startswith("../"):
        return sp[len("../"):]
    return ctx.workspace_name + "/" + sp

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
    is_win = _is_windows(ctx)
    if is_win:
        classpath_str = sep.join([f.short_path for f in classpath.to_list()])
        jvm_flags = "".join([f + " " for f in ctx.attr.jvm_flags])
        content = _LAUNCHER_TEMPLATE_BAT.format(
            elide = elide.binary.short_path,
            jvm_flags = jvm_flags,
            classpath = classpath_str,
            main_class = ctx.attr.main_class,
        )
        launcher = ctx.actions.declare_file(ctx.label.name + "_launcher.bat")
    else:
        # Pass each classpath entry as an rlocation key; the launcher resolves
        # them at runtime via the bash runfiles library and joins with `sep`.
        cp_keys = " ".join([shell.quote(_rlocation_path(ctx, f)) for f in classpath.to_list()])
        jvm_flags = "".join([shell.quote(f) + " " for f in ctx.attr.jvm_flags])
        content = _LAUNCHER_TEMPLATE_SH.format(
            runfiles_init = _RUNFILES_INIT,
            elide = shell.quote(_rlocation_path(ctx, elide.binary)),
            jvm_flags = jvm_flags,
            classpath = cp_keys,
            sep = sep,
            main_class = shell.quote(ctx.attr.main_class),
        )
        launcher = ctx.actions.declare_file(ctx.label.name + "_launcher.sh")
    ctx.actions.write(output = launcher, content = content, is_executable = True)
    runfiles = ctx.runfiles(
        files = [output_jar, launcher],
        transitive_files = depset(transitive = [elide.tool_files, classpath]),
    ).merge(ctx.attr._runfiles_library[DefaultInfo].default_runfiles)
    return launcher, runfiles

# Unlike build_launcher, test launchers keep short_path (no rlocation): they only
# run under `bazel test` (cwd = runfiles tree), never as a persistent worker.
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
    "resource_strip_prefix": attr.string(
        doc = "Workspace-root-relative path prefix stripped from each `resources` " +
              "entry when computing its in-JAR location (mirrors " +
              "java_library.resource_strip_prefix). Empty -> use the full short_path.",
    ),
    "resources": attr.label_list(
        doc = "Resource files packaged into the output JAR alongside compiled classes.",
        allow_files = True,
    ),
    "runtime_deps": attr.label_list(
        doc = "Runtime-only dependencies (excluded from compile classpath).",
        providers = [[JavaInfo]],
    ),
    "_classpath_cache": attr.label(
        default = "@rules_elide//config/javac:classpath_cache",
        providers = [BuildSettingInfo],
        doc = "Build setting opting `elide javac` worker compiles into the " +
              "digest-keyed classpath cache (`--classpath-cache`).",
    ),
    "_incremental": attr.label(
        default = "@rules_elide//config/kotlinc:incremental",
        providers = [BuildSettingInfo],
        doc = "Build setting opting kotlinc compiles into incremental " +
              "compilation (compile-to-dir + cache-dir + pack-to-jar).",
    ),
    "_use_workers": attr.label(
        default = "@rules_elide//elide:use_workers",
        providers = [BuildSettingInfo],
        doc = "Build setting toggling Bazel persistent workers for the elide " +
              "javac/kotlinc compile actions.",
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
    "_runfiles_library": attr.label(
        default = "@bazel_tools//tools/bash/runfiles",
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
