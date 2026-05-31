# SPDX-License-Identifier: Apache-2.0

"""Source-code formatter rule for rules_elide.

`elide_format` is a runnable target (`bazel run`) that formats its `srcs`
in place via the embedded Elide formatters:

  - `.java` sources -> `elide javaformat` (google-java-format)
  - `.kt` / `.kts` sources -> `elide ktfmt`

A target may not mix languages; split into two `elide_format` targets if
the source set spans both.
"""

load("@bazel_skylib//lib:shell.bzl", "shell")
load("//elide/private:compile_common.bzl", "TOOLCHAIN_TYPE")

_LAUNCHER_TEMPLATE = """\
#!/bin/sh
set -eu
if [ -z "${{BUILD_WORKSPACE_DIRECTORY:-}}" ]; then
  echo "elide_format must be invoked via 'bazel run'." >&2
  exit 64
fi
cd "$BUILD_WORKSPACE_DIRECTORY"
exec {elide} {tool} -- {srcs} "$@"
"""

def _classify(srcs):
    java = [f for f in srcs if f.path.endswith(".java")]
    kotlin = [f for f in srcs if f.path.endswith(".kt") or f.path.endswith(".kts")]
    return java, kotlin

def _elide_format_impl(ctx):
    elide = ctx.toolchains[TOOLCHAIN_TYPE].elide_info
    java, kotlin = _classify(ctx.files.srcs)
    if java and kotlin:
        fail(
            "elide_format target {} mixes .java and .kt/.kts sources; split into two targets.".format(ctx.label),
        )
    if java:
        tool = "javaformat"
        targets = java
    elif kotlin:
        tool = "ktfmt"
        targets = kotlin
    else:
        fail("elide_format target {} has no .java/.kt/.kts sources.".format(ctx.label))

    src_args = " ".join([shell.quote(f.short_path) for f in targets])
    content = _LAUNCHER_TEMPLATE.format(
        elide = shell.quote(elide.binary.short_path),
        tool = tool,
        srcs = src_args,
    )
    launcher = ctx.actions.declare_file(ctx.label.name + "_format.sh")
    ctx.actions.write(output = launcher, content = content, is_executable = True)
    runfiles = ctx.runfiles(
        files = [launcher] + ctx.files.srcs,
        transitive_files = elide.tool_files,
    )
    return [DefaultInfo(executable = launcher, runfiles = runfiles, files = depset([launcher]))]

elide_format = rule(
    implementation = _elide_format_impl,
    attrs = {
        "srcs": attr.label_list(
            doc = "Source files to format. All must be .java or all .kt/.kts.",
            allow_files = [".java", ".kt", ".kts"],
            mandatory = True,
        ),
    },
    toolchains = [TOOLCHAIN_TYPE],
    executable = True,
)
