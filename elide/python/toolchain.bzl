# SPDX-License-Identifier: Apache-2.0
"""Opt-in rules_python runtime backed by an Elide Python overlay."""

load("@bazel_skylib//lib:selects.bzl", "selects")
load("@rules_python//python:py_runtime.bzl", "py_runtime")
load("@rules_python//python:py_runtime_pair.bzl", "py_runtime_pair")

visibility("public")

def _key(ctx, file):
    return file.short_path[3:] if file.short_path.startswith("../") else ctx.workspace_name + "/" + file.short_path

def _launcher_impl(ctx):
    files = ctx.files.runtime_files
    if not any([f.short_path.endswith("/conf/components/python") for f in files]):
        fail("Python component marker missing: install Elide with python = True and pass its elide_python_files target.")
    helper_runfiles = ctx.attr._runfiles[DefaultInfo].default_runfiles
    helpers = helper_runfiles.files.to_list() + [entry.target_file for entry in helper_runfiles.root_symlinks.to_list()]
    helper = [f for f in helpers if f.basename == "runfiles.bash"][0]
    launcher = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.expand_template(
        template = ctx.file._template,
        output = launcher,
        # Template delimiters, not canonical repository labels.
        # buildifier: disable=canonical-repository
        substitutions = {"@@ELIDE@@": _key(ctx, ctx.file.elide), "@@RUNFILES@@": _key(ctx, helper)},
        is_executable = True,
    )
    return [DefaultInfo(
        executable = launcher,
        runfiles = ctx.runfiles(files = files + [ctx.file.elide, helper]).merge(ctx.attr._runfiles[DefaultInfo].default_runfiles),
    )]

_launcher = rule(
    implementation = _launcher_impl,
    executable = True,
    attrs = {
        "elide": attr.label(allow_single_file = True, mandatory = True),
        "runtime_files": attr.label(allow_files = True, mandatory = True),
        "_runfiles": attr.label(default = Label("@bazel_tools//tools/bash/runfiles")),
        "_template": attr.label(default = Label(":launcher.sh.tpl"), allow_single_file = True),
    },
)

def register_elide_python_toolchain(name, elide, runtime_files, target_compatible_with, visibility = None):
    """Declare an Elide Python runtime; register its name from MODULE.bazel.

    Args:
        name: Toolchain target name to register with register_toolchains.
        elide: Matching distribution's bin/elide label (target platform).
        runtime_files: Same distribution's elide_python_files label, with overlay installed.
        target_compatible_with: OS and CPU constraints matching that distribution.
        visibility: Visibility of generated targets.
    """
    _launcher(
        name = name + "_launcher",
        elide = elide,
        runtime_files = runtime_files,
        visibility = visibility,
    )
    py_runtime(
        name = name + "_runtime",
        interpreter = ":" + name + "_launcher",
        files = [runtime_files],
        python_version = "PY3",
        interpreter_version_info = {"major": "3", "minor": "13"},
        implementation_name = "graalpy",
        visibility = visibility,
    )
    py_runtime_pair(
        name = name + "_pair",
        py3_runtime = ":" + name + "_runtime",
        visibility = visibility,
    )

    # Do not intercept targets requesting a different Python language version.
    for suffix, version in [("default", ""), ("313", "3.13")]:
        native.config_setting(
            name = name + "_version_" + suffix,
            flag_values = {"@rules_python//python/config_settings:python_version": version},
            visibility = visibility,
        )
    selects.config_setting_group(
        name = name + "_version",
        match_any = [":" + name + "_version_default", ":" + name + "_version_313"],
        visibility = visibility,
    )
    native.toolchain(
        name = name,
        toolchain = ":" + name + "_pair",
        toolchain_type = "@rules_python//python:toolchain_type",
        target_compatible_with = target_compatible_with,
        target_settings = [":" + name + "_version"],
        visibility = visibility,
    )
